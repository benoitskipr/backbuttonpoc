import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// illustrates a quick fix idea that would hide the native back button on subsequent web pages
const bool quickFixByJustHidingNativeButton = false;

// url to change to the test one
String get urlToLoadInitially =>
    "https://benoitskipr.github.io/backbuttonpoc/${quickFixByJustHidingNativeButton ? "poc-noback.html" : "poc.html"}";
const String jsBackButtonCallback = "nativeBack";

//
Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const MaterialApp(home: HomePage()));
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HOMEPAGE',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey.shade100,
        shadowColor: Colors.transparent,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WebView()),
          ),
          style: ElevatedButton.styleFrom(
              elevation: 12.0, textStyle: const TextStyle(color: Colors.white)),
          child: const Text('open the webview'),
        ),
      ),
    );
  }
}

class WebView extends StatefulWidget {
  const WebView({super.key});

  @override
  createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? _webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  double progress = 0;

  // is updated by the webView controller on page change
  bool hasHistory = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _interceptNativeBackButton,
      child: Scaffold(
        appBar: quickFixByJustHidingNativeButton
            ? AppBar(
                backgroundColor: Colors.grey.shade100,
                shadowColor: Colors.transparent,
                leading: (quickFixByJustHidingNativeButton && hasHistory)
                    ? null
                    : BackButton(
                        color: Colors.blue,
                        onPressed: hasHistory
                            ? () => _webViewController?.goBack()
                            : null,
                      ),
              )
            : null,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: [
                    _buildWebView(),
                    progress < 1.0
                        ? LinearProgressIndicator(value: progress)
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
              /*ArrowBar(
                hasHistory: hasHistory,
                webViewController: _webViewController,
              ),*/
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      key: webViewKey,
      initialUrlRequest: URLRequest(
        url: Uri.parse(urlToLoadInitially),
      ),
      // or it can load html but that first page does not count
      // in the history,
      // better to use an external page with initialUrlRequest
      /*initialData: InAppWebViewInitialData(
        data: '<html>'
            '<head>'
            '<meta name="viewport" content="initial-scale=1.0" />'
            '</head>'
            '<button onclick=history.back()">history.back()</button>'
            '<button onclick="location.href = \'https://www.google.com\'">navigate out</button>'
            '<a href="https://www.google.com">navigate out</a>'
            '</html>',
      ),*/
      initialOptions: options,
      onWebViewCreated: (controller) {
        _webViewController = controller;
        _webViewController!.addJavaScriptHandler(
          handlerName: jsBackButtonCallback,
          callback: (_) => Navigator.pop(context),
        );
      },
      androidOnPermissionRequest: (controller, origin, resources) async {
        return PermissionRequestResponse(
            resources: resources,
            action: PermissionRequestResponseAction.GRANT);
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async =>
          NavigationActionPolicy.ALLOW,
      onLoadStop: (controller, url) async {
        hasHistory = await _webViewController!.canGoBack();
        setState(() {});
      },
      onLoadError: (controller, url, code, message) {},
      onProgressChanged: (controller, progress) {
        setState(() => this.progress = progress / 100);
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint(consoleMessage.message);
        _showingConsoleAsAlertDialog(context, consoleMessage.message);
      },
    );
  }

  // WillPopScope intercepts the physical back button press on Android
  // it navigates back inside the webview if this one has history,
  // otherwise goes back to the previous native page before this webview page
  Future<bool> _interceptNativeBackButton() async {
    if (await (_webViewController?.canGoBack() ?? Future.value(false))) {
      var webHistory = await _webViewController?.getCopyBackForwardList();
      if ((webHistory?.currentIndex ?? 0) <= 1) {
        return true;
      }
      await _webViewController?.goBack();
      return false;
    }
    return true;
  }

  void _showingConsoleAsAlertDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Alert"),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

/*
class ArrowBar extends StatelessWidget {
  const ArrowBar({
    Key? key,
    required this.hasHistory,
    required this.webViewController,
  }) : super(key: key);

  final bool hasHistory;
  final InAppWebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return ButtonBar(
      alignment: MainAxisAlignment.center,
      children: <Widget>[
        ElevatedButton(
          onPressed: hasHistory ? () => webViewController?.goBack() : null,
          child: const Icon(Icons.arrow_back),
        ),
        ElevatedButton(
          child: const Icon(Icons.arrow_forward),
          onPressed: () {
            webViewController?.goForward();
          },
        ),
        ElevatedButton(
          child: const Icon(Icons.refresh),
          onPressed: () {
            webViewController?.reload();
          },
        ),
      ],
    );
  }
}
*/
