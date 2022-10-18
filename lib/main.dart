import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'dart:convert';
import 'dart:async';
import 'firebase_options.dart';

const bool kProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool kDebugMode = !kReleaseMode && !kProfileMode;

// Firebase solo funciona en estas plataformas
final kFirebase = (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS)
    ? true
    : false;

const host = (kDebugMode)
    ? 'http://localhost:8000/api'
    : 'http://juhegue.duckdns.org:8080/api';

void main() async {
  if (kFirebase) {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Retrieve Text Input',
      home: MyCustomForm(),
    );
  }
}

// Define un widget de formulario personalizado
class MyCustomForm extends StatefulWidget {
  const MyCustomForm({super.key});

  @override
  State<MyCustomForm> createState() => _MyCustomFormState();
}

// Define la clase State correspondiente. Esta clase contendrá los datos relacionados con
// nuestro formulario.
class _MyCustomFormState extends State<MyCustomForm> {
  // Crea un controlador de texto. Lo usaremos para recuperar el valor actual
  // del TextField!
  final pwdController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Autostar solo en modo release
    if (kReleaseMode) {
        initAutoStart();
    }
  }

  Future<void> initAutoStart() async {
    try {
      //check auto-start availability.
      var test = await (isAutoStartAvailable as FutureOr<bool>);
      debugPrint(test.toString());
      //if available then navigate to auto-start setting page.
      if (test) await getAutoStartPermission();
    } on PlatformException catch (e) {
      debugPrint(e.toString());
    }
    if (!mounted) return;
  }

  @override
  void dispose() {
    // Limpia el controlador cuando el Widget se descarte
    pwdController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Notas Notifica',
        theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ),
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Acceso Notas Notifica'),
            ),
            body: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 70),
                    child: Image.asset(
                      'assets/images/notas_avisos.png',
                      width: 80,
                      height: 80,
                    ),
/*                    
                    child: const FlutterLogo(
                      size: 40,
                    ),
*/
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(90.0),
                        ),
                        labelText: 'Email',
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: TextField(
                      controller: pwdController,
                      obscureText: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(90.0),
                        ),
                        labelText: 'Contraseña',
                      ),
                    ),
                  ),
                  Container(
                    height: 80,
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Aceptar'),
                        onPressed: () async {
                          try {
                            // obtener el token firebase
                            final fcmToken = (kFirebase)
                                ? await FirebaseMessaging.instance.getToken()
                                : '<fcm_token>';
                            debugPrint(fcmToken);

                            var webToken = await getWebToken(
                                emailController.text, pwdController.text);

                            sendFcmToken(webToken, fcmToken!);

                            // y cerrar la app
                            SystemChannels.platform
                                .invokeMethod('SystemNavigator.pop');
                          } on Exception catch (e, _) {
                            _showErrorDialog(context, e.toString());
                            debugPrint(e.toString());
                          }
                        }),
                  ),
/*                  
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
*/
                ],
              ),
            )));
  }
}

Future<void> _showErrorDialog(BuildContext context, String mensaje) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Error'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(mensaje),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Aceptar'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<String> getWebToken(String email, String pwd) async {
  final Map<String, dynamic> body = {'username': email, 'password': pwd};
  final encoding = Encoding.getByName('utf-8');

  final response = await http.post(
    Uri.parse('$host/login/'),
    headers: <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
    },
    body: body,
    encoding: encoding,
  );

  debugPrint('${response.statusCode} ${response.body}');
  if (response.statusCode == 200) {
    return jsonDecode(response.body)['token'];
  } else {
    throw Exception('HTTP ${response.statusCode}:${response.body}.');
  }
}

Future<bool> sendFcmToken(String webToken, String fcmToken) async {
  final Map<String, dynamic> body = {'fcm_token': fcmToken};
  final encoding = Encoding.getByName('utf-8');

  final response = await http.post(
    Uri.parse('$host/token_fcm/'),
    headers: <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
      'Authorization': 'Token $webToken',
    },
    body: body,
    encoding: encoding,
  );

  debugPrint('${response.statusCode} ${response.body}');

  if (response.statusCode == 200) {
    return true;
  } else {
    throw Exception('ERROR:${response.statusCode}:${response.body}.');
  }
}

