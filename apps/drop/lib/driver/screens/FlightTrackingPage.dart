import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drop/driver/main.dart';
import 'package:drop/driver/utils/Colors.dart';
import 'package:drop/driver/utils/Extensions/app_common.dart';
import 'package:drop/driver/utils/Extensions/extension.dart';
import 'package:drop/driver/utils/Extensions/int_extensions.dart';

class FlightTrackingService {
  final String apiKey = 'f1b540bbbacfe049afe1efd635ec9a3b';
  final String baseUrl = 'http://api.aviationstack.com/v1/flights';

  Future<Map<String, dynamic>> fetchFlightInfo(String flightIata) async {
    try {
      final url = Uri.parse('$baseUrl?access_key=$apiKey&flight_iata=$flightIata');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null && data['data'].isNotEmpty) {
          return data['data'][0];
        } else {
          throw Exception('No flight data found');
        }
      } else {
        throw Exception('Failed to load flight information. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching flight information: $e');
    }
  }
}

class FlightTrackingScreen extends StatefulWidget {
  final String? flightNumber;

  FlightTrackingScreen({this.flightNumber});

  @override
  _FlightTrackingScreenState createState() => _FlightTrackingScreenState();
}

class _FlightTrackingScreenState extends State<FlightTrackingScreen> {
  final FlightTrackingService _flightService = FlightTrackingService();
  Map<String, dynamic>? _flightData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero).then((val) {
      _fetchFlightInfo();
    });
  }

  void _fetchFlightInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final flightInfo = await _flightService.fetchFlightInfo(widget.flightNumber ?? '');
      setState(() {
        _flightData = flightInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String formatScheduledDeparture(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime == 'N/A') {
      return 'N/A';
    }

    try {
      final dateTime = DateTime.parse(scheduledTime).toLocal();
      final formatter = DateFormat('MMMM d, yyyy, h:mm a');
      return formatter.format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(language.flightTacking, style: boldTextStyle(color: appTextPrimaryColorWhite)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                )
              else if (_flightData != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(language.overRollFlightStatus, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        10.height,
                        _buildDetailRow(language.flightDate, _flightData?['flight_date'] ?? 'N/A'),
                        _buildDetailRow(language.status, _flightData?['flight_status'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
                12.height,
                if (_flightData?['departure'] != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(language.DepInformation, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          10.height,
                          _buildDetailRow(language.airport, "${_flightData?['departure']['airport'] ?? 'N/A'} (${_flightData?['departure']['iata']})"),
                          _buildDetailRow(language.terminalAddress, "${_flightData?['departure']['terminal'] ?? 'N/A'}, Gate ${_flightData?['departure']['gate'] ?? 'N/A'}"),
                          _buildDetailRow(language.scheduledDep, formatScheduledDeparture(_flightData?['departure']['scheduled'] ?? 'N/A')),
                          _buildDetailRow(language.estimatedDep, formatScheduledDeparture(_flightData?['departure']['estimated_runway'] ?? 'N/A')),
                          _buildDetailRow(language.actualDep, formatScheduledDeparture(_flightData?['departure']['actual_runway'] ?? 'N/A')),
                        ],
                      ),
                    ),
                  ),
                  12.height,
                ],
                if (_flightData?['arrival'] != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(language.AircraftInfo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          10.height,
                          _buildDetailRow(language.airport, _flightData?['arrival']['airport'] ?? 'N/A'),
                          _buildDetailRow(language.terminalAddress, "${_flightData?['arrival']['terminal'] ?? 'N/A'}"),
                          _buildDetailRow(language.bagClaim, _flightData?['arrival']['baggage'] ?? 'N/A'),
                          _buildDetailRow(language.scheduledArri, formatScheduledDeparture(_flightData?['arrival']['scheduled'] ?? 'N/A')),
                          _buildDetailRow(language.estimatedArri, formatScheduledDeparture(_flightData?['arrival']['estimated'] ?? 'N/A')),
                          _buildDetailRow(language.actualArri, formatScheduledDeparture(_flightData?['arrival']['actual_runway'] ?? 'N/A')),
                        ],
                      ),
                    ),
                  ),
                  12.height,
                ],
                if (_flightData?['airline'] != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(language.AirFlightDetails, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          10.height,
                          _buildDetailRow(language.airline, "${_flightData?['airline']['name'] ?? 'N/A'} (${_flightData?['airline']['iata']} / ${_flightData?['airline']['icao']})"),
                          _buildDetailRow(language.flightNumber, "${_flightData?['flight']['iata'] ?? 'N/A'} (${_flightData?['flight']['number']})"),
                        ],
                      ),
                    ),
                  ),
                  12.height,
                ],
                if (_flightData?['aircraft'] != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(language.AircraftInfo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          10.height,
                          _buildDetailRow(language.registration, _flightData?['aircraft']['registration'] ?? 'N/A'),
                          _buildDetailRow('${language.AirCraftType} (IATA/ICAO)', _flightData?['aircraft']['iata'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                ]
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
