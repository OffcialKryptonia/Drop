/**
 * Starter ride types an admin can add to a region in one tap. They are created switched OFF with
 * placeholder naira fares, so nothing goes live until the admin reviews the prices. All editable.
 */
export const STARTER_RIDE_TYPES = [
  { name: "DROP Go", category: "car", capacity: 4, base_fare: 500, minimum_fare: 800, per_distance: 120, per_minute_drive: 15, description: "Everyday low-cost rides." },
  { name: "DROP Comfort", category: "car", capacity: 4, base_fare: 700, minimum_fare: 1100, per_distance: 160, per_minute_drive: 20, description: "Newer cars with air conditioning." },
  { name: "DROP XL", category: "van", capacity: 6, base_fare: 900, minimum_fare: 1500, per_distance: 200, per_minute_drive: 25, description: "Six seats or more for families and groups." },
  { name: "DROP Premium", category: "car", capacity: 4, base_fare: 1500, minimum_fare: 2500, per_distance: 300, per_minute_drive: 35, description: "Executive saloon or SUV." },
  { name: "DROP Bike", category: "bike", capacity: 1, base_fare: 200, minimum_fare: 400, per_distance: 60, per_minute_drive: 8, description: "Motorcycle taxi that beats traffic. Check local rules before enabling." },
  { name: "DROP Keke", category: "tricycle", capacity: 3, base_fare: 250, minimum_fare: 400, per_distance: 70, per_minute_drive: 8, description: "Tricycle for short local trips. Check local rules before enabling." },
  { name: "DROP Shuttle", category: "bus", capacity: 14, base_fare: 300, minimum_fare: 500, per_distance: 50, per_minute_drive: 5, description: "Shared van priced per seat." },
  { name: "DROP Women", category: "car", capacity: 4, base_fare: 550, minimum_fare: 850, per_distance: 130, per_minute_drive: 16, description: "Women drivers for women passengers." },
  { name: "DROP Delivery", category: "delivery", capacity: 1, base_fare: 400, minimum_fare: 700, per_distance: 90, per_minute_drive: 10, description: "Parcels by bike or car." },
  { name: "DROP Hourly", category: "car", capacity: 4, base_fare: 4000, minimum_fare: 4000, per_distance: 0, per_minute_drive: 60, description: "Hire a car and driver by the hour." },
  { name: "DROP Outstation", category: "car", capacity: 4, base_fare: 3000, minimum_fare: 8000, per_distance: 150, per_minute_drive: 10, description: "Intercity trips with route pricing." },
  { name: "DROP Airport", category: "car", capacity: 4, base_fare: 1500, minimum_fare: 3000, per_distance: 140, per_minute_drive: 15, description: "Fixed-price airport pickups and drops." },
] as const;
