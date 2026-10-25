import 'package:flutter/material.dart';
import 'package:miru/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return const Setting();
  }
}

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _Setting();
}

class _Setting extends State<Setting> {
  final Uri _url = Uri.parse('https://docs.google.com/document/d/e/2PACX-1vQ4N2TuQ-CWTslNSqdtDhuvJGAB0iUJW9OldC99FGnT0vO8ILwd69mQFSuHENvrZPSih2XWW8IrkN0r/pub'); // Define the URI

  Future<void> _launchUrl() async {
    try {
      if (await launchUrl(_url)) return;
    } catch (_) {

    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the privacy policy. Please try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(15.0),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SpaceBox(height: 20, width: 20),
            Text("Scan barcodes or search companies to learn more about its animal, environmental, and human labor ethicality scores.\n\nEarn tokens, shop items, and customize your avatar in home."),
            SpaceBox(height: 20, width: 20),
            Text(
              'Creators: Mili Gupta & Lumi Yaida\n\nStack: Flutter/Dart, OpenAI API, Rive'
            ),
            SpaceBox(height: 20, width: 20),
            Text.rich(
              TextSpan(
                text: 'For additional feedback and questions, ',
                children: <TextSpan>[
                  TextSpan(
                    text: 'miru.ethical.scanner@gmail.com',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: '.',
                  ),
                ],
              ),
            ),
            SpaceBox(height: 20, width: 20),
            InkWell(
              onTap: _launchUrl,
              child: const Text(
                'Privacy Policy Document',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ]
          ),
        )
      ),
    );
  }
}
