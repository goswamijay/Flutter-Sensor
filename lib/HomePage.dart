import 'dart:async';
import 'dart:core';
import 'package:flutter/foundation.dart' as foundation;

import 'package:environment_sensors/environment_sensors.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'SensorData.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> sensorName = [
    "Accelerometer sensor",
    "Gyroscope Sensor",
    "Magnetometer Sensor",
    "Humidity Sensor",
    "Temperature Sensor",
    "Light Sensor",
    "Pressure Sensor",
    "Pedometer Sensor",
    "Proximity Sensor",
    "Geo Locator Sensor"
  ];

  List<double>? _userAccelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  int _isNear = 0;
  late StreamSubscription<dynamic> _streamSubscription;

  double longitude = 0.00;
  double latitude = 0.00;

  bool _tempAvailable = false;
  bool _humidityAvailable = false;
  bool _lightAvailable = false;
  bool _pressureAvailable = false;
  final environmentSensors = EnvironmentSensors();

  late Stream<StepCount> _stepCountStream;
  late Stream<PedestrianStatus> _pedestrianStatusStream;
  String _status = '?', _steps = '?';

  @override
  Widget build(BuildContext context) {
    final userAccelerometer = _userAccelerometerValues
        ?.map((double v) => v.toStringAsFixed(1))
        .toList();
    final gyroscope =
        _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final magnetometer =
        _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();

    List<Widget> sensorDescription = [
      Text("UserAccelerometer: $userAccelerometer"),
      Text(
        "UserGyroscope Sensor : $gyroscope",
      ),
      Text(
        "Magnetometer Sensor : $magnetometer",
      ),
      (_humidityAvailable)
          ? StreamBuilder<double>(
              stream: environmentSensors.humidity,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return Text(
                    'The Current Humidity is: ${snapshot.data?.toStringAsFixed(2)}%');
              })
          : const Text('No relative humidity sensor found'),
      (_tempAvailable)
          ? StreamBuilder<double>(
              stream: environmentSensors.temperature,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return Text(
                    'The Current Temperature is: ${snapshot.data?.toStringAsFixed(2)}%');
              })
          : const Text('No relative Temperature sensor found'),
      (_lightAvailable)
          ? StreamBuilder<double>(
              stream: environmentSensors.light,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return Text(
                    'The Current Light is: ${snapshot.data?.toStringAsFixed(2)}%');
              })
          : const Text('No relative Light sensor found'),
      (_pressureAvailable)
          ? StreamBuilder<double>(
              stream: environmentSensors.pressure,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return Text(
                    'The Current Pressure is: ${snapshot.data?.toStringAsFixed(2)}%');
              })
          : const Text('No relative Pressure sensor found'),
      Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Steps Taken',
                  style: TextStyle(fontSize: 20),
                ),
                Text(
                  _steps,
                  style: const TextStyle(fontSize: 30),
                ),
              ],
            ),
          ),
          const VerticalDivider(
            width: 100,
            thickness: 1,
            color: Colors.black,
          ),
          Expanded(
            child: Column(
              children: [
                const FittedBox(
                  child: Text(
                    'Pedestrian Status',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Icon(
                  _status == 'walking'
                      ? Icons.directions_walk
                      : _status == 'stopped'
                          ? Icons.accessibility_new
                          : Icons.error,
                  size: 50,
                ),
                Center(
                  child: Text(
                    _status,
                    style: _status == 'walking' || _status == 'stopped'
                        ? const TextStyle(fontSize: 30)
                        : const TextStyle(fontSize: 20, color: Colors.red),
                  ),
                )
              ],
            ),
          )
        ],
      ),
      Text('Proximity sensor, is near :- $_isNear'),
      Row(
        children: [
          Expanded(child: Text("Longitude: $longitude ")),
          Expanded(child: Text("Latitude: $latitude ")),
          Expanded(
              child: ElevatedButton(
                  onPressed: () {
                    getCurrentLocation();
                  },
                  child: const Text("Update")))
        ],
      )
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mobile Sensors"),
      ),
      body: ListView.builder(
          itemCount: sensorName.length,
          itemBuilder: (builder, index) {
            return ExpansionTile(
              backgroundColor: Colors.grey.shade50,
              title: Text(
                sensorName[index],
              ),
              children: [
                ListTile(
                  title: sensorDescription[index],
                  trailing: IconButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text(sensorName[index]),
                                content: Text(sensorDescriptions[index]),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            });
                      },
                      icon: const Icon(Icons.info)),
                )
              ],
            );
          }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
    initPlatformState1();
    environmentSensorState();
    proximityData();
    getCurrentLocation();
  }

  Future<void> environmentSensorState() async {
    _streamSubscriptions.add(
      userAccelerometerEvents.listen(
        (UserAccelerometerEvent event) {
          setState(() {
            _userAccelerometerValues = <double>[event.x, event.y, event.z];
          });
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Accelerometer Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );

    _streamSubscriptions.add(
      gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
          });
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support User Gyroscope Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );
    _streamSubscriptions.add(
      magnetometerEvents.listen(
        (MagnetometerEvent event) {
          setState(() {
            _magnetometerValues = <double>[event.x, event.y, event.z];
          });
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Magnetometer Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );
  }

  Future<void> initPlatformState() async {
    bool tempAvailable;
    bool humidityAvailable;
    bool lightAvailable;
    bool pressureAvailable;

    tempAvailable = await environmentSensors
        .getSensorAvailable(SensorType.AmbientTemperature);
    humidityAvailable =
        await environmentSensors.getSensorAvailable(SensorType.Humidity);
    lightAvailable =
        await environmentSensors.getSensorAvailable(SensorType.Light);
    pressureAvailable =
        await environmentSensors.getSensorAvailable(SensorType.Pressure);

    setState(() {
      _tempAvailable = tempAvailable;
      _humidityAvailable = humidityAvailable;
      _lightAvailable = lightAvailable;
      _pressureAvailable = pressureAvailable;
    });
  }

  void onStepCount(StepCount event) {
    setState(() {
      _steps = event.steps.toString();
    });
  }

  void onPedestrianStatusChanged(PedestrianStatus event) {
    setState(() {
      _status = event.status;
    });
  }

  void onPedestrianStatusError(error) {
    setState(() {
      _status = 'Pedestrian Status not available';
    });
  }

  void onStepCountError(error) {
    setState(() {
      _steps = 'Step Count not available';
    });
  }

  void onStepCountMain() {
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;

    _pedestrianStatusStream
        .listen(onPedestrianStatusChanged)
        .onError(onPedestrianStatusError);

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(onStepCount).onError(onStepCountError);

    if (!mounted) return;
  }

  void initPlatformState1() async {
    if (await Permission.activityRecognition.isGranted) {
      onStepCountMain();
    } else {
      await Permission.activityRecognition.request().isGranted.then((value) {
        onStepCountMain();
      });
    }
  }

  Future<void> proximityData() async {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (foundation.kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };
    _streamSubscription = ProximitySensor.events.listen((int event) {
      setState(() {
        _isNear = event;
      });
    });
  }

  void getCurrentLocation() async {
    await Permission.location.request().isGranted.then((value) async {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        print("Error: $e");
      }

      if (position != null) {
        setState(() {
          latitude = position!.latitude;
          longitude = position!.longitude;
        });

        print("Latitude: $latitude, Longitude: $longitude");
      } else {}
    });
  }
}
