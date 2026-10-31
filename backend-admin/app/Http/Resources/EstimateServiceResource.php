<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;
use App\Models\Coupon;
use App\Models\User;
use Carbon\Carbon;

class EstimateServiceResource extends JsonResource
{
    public static $dropoffTimeInSeconds = null;
    public static $dropoff_distance_in_meters = null;

    public function toArray($request)
    {
        $distance_unit = optional($this->region)->distance_unit ?? 'km';
        $dropoff_distance_in_meters = self::$dropoff_distance_in_meters ?? 0;

        if ($distance_unit === 'mile') {
            // km → miles
            $distance_in_unit = $dropoff_distance_in_meters / 1609.344;
        }else{
            $distance_in_unit = $dropoff_distance_in_meters / 1000;
        }
        $dropoff_time_in_seconds = self::$dropoffTimeInSeconds ?? 0;

        $multiLocation = $this['multi_drop_location'] ?? request('multi_location', []);
        if (is_string($multiLocation)) {
            $multiLocation = json_decode($multiLocation, true);
        }

        $user = User::where('user_type', 'admin')->first();
        $date_time = Carbon::now($user->timezone)->format('Y-m-d H:i');
        $surge_price = getSurgePrice($date_time,$this->id);
        $service_data = [
            'id'                => $this->id,
            'service_id'        => $this->id,
            'name'              => $this->name,
            'region_id'         => $this->region_id,
            'distance_unit'     => $distance_unit,
            'dropoff_distance_in_km' => round($distance_in_unit,2),
            'duration'          => round($dropoff_time_in_seconds/60,2),
            'capacity'          => $this->capacity,
            'base_fare'         => $this->base_fare,
            'minimum_fare'      => $this->minimum_fare,
            'minimum_distance'  => $this->minimum_distance,
            'per_distance'      => $this->per_distance,
            'per_minute_drive'  => $this->per_minute_drive,
            'per_minute_wait'   => $this->per_minute_wait,
            'waiting_time_limit'=> $this->waiting_time_limit,
            'cancellation_fee'  => $this->cancellation_fee,
            'payment_method'    => $this->payment_method,
            'service_image'     => getSingleMedia($this, 'service_image',null),
            'service_marker'     => getServiceSingleMedia($this, 'service_marker',null),
            'status'            => $this->status,
            'created_at'        => $this->created_at,
            'updated_at'        => $this->updated_at,
            'description'       => $this->description,
            'commission_type'   => $this->commission_type,
            'admin_commission'  => $this->admin_commission,
            'fleet_commission'  => $this->fleet_commission,
            'coupon_discount'   => optional($this->driverRideRequestDetail),
        ];
        $coupon = null;
        if($request->coupon_code){
            $coupon = Coupon::where('code',$request->coupon_code)->first();

        }
        // caclulate ride
        $ridefee = calculateNewRideFares( $distance_in_unit,$dropoff_time_in_seconds,$service_data,$surge_price );

        if ($ridefee['total_amount'] == $service_data['minimum_fare']) {
            $service_data['base_fare'] = $ridefee['total_amount'];
        }
        $discount_amount = 0;
        $payable_amount = $ridefee['total_amount'];
        $ridefee['discount_amount'] = 0;
        $ridefee['total_amount_after_discount'] = $payable_amount;

        if ($coupon && $ridefee['is_zoneprice'] == 0) {
            $apply_coupon = false;
            switch ($coupon->coupon_type) {
                case 'all':
                    $apply_coupon = true;
                    break;

                case 'first_ride':
                    $user = auth()->user();
                    if ($user && $user->completedRides()->count() === 0) {
                        $apply_coupon = true;
                    }
                    break;

                case 'region_wise':
                    $regions = (array) json_decode($coupon->region_ids, true);
                    if (in_array((int)$this->region_id, $regions)) {
                        $apply_coupon = true;
                    }
                    break;

                case 'service_wise':
                    $services = (array) json_decode($coupon->service_ids, true);
                    if (in_array((int)$service_data['id'], $services)) {
                        $apply_coupon = true;
                    }
                    break;
            }

            if ($apply_coupon && $coupon->minimum_amount <= $payable_amount) {

                if ($coupon->discount_type === 'percentage') {
                    $discount_amount = ($payable_amount * $coupon->discount) / 100;
                } else {
                    $discount_amount = $coupon->discount;
                }

                // Cap by coupon max discount
                if ($coupon->maximum_discount > 0) {
                    $discount_amount = min($discount_amount, $coupon->maximum_discount);
                }

                // Cap by order amount (VERY IMPORTANT)
                $discount_amount = min($discount_amount, $payable_amount);
                $payable_amount -= $discount_amount;
            }

            $ridefee['discount_amount'] = round($discount_amount, 2);
            $ridefee['total_amount_after_discount'] = round($payable_amount, 2);
        }

        $commission_type = $this->commission_type ?? 0;
        $admin_commission = $this->admin_commission ?? 0;

         if( $commission_type == 'percentage' ) {
            $admin_commission = $admin_commission ? (  $ridefee['total_amount_after_discount']/ 100) * $admin_commission: 0;
        }
        $ridefee['admin_earning'] = $admin_commission;
        $ridefee['coins_used'] = 0;
        if($request->use_coins){
                $ridefee['coins_used'] = $request->use_coins;
                $ridefee['total_amount_after_discount'] = $payable_amount - $request->use_coins;
        }

        return array_merge($service_data, $ridefee);
    }
}
