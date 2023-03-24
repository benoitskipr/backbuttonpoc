import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const MaterialApp(home: Webview()));
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MaterialButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Webview()),
          ),
        ),
      ),
    );
  }
}

class Webview extends StatefulWidget {
  const Webview({super.key});

  @override
  createState() => _WebviewState();
}

class _WebviewState extends State<Webview> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
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

  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  bool showBackButton = false;

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await (webViewController?.canGoBack() ?? Future.value(false))) {
          var webHistory = await webViewController?.getCopyBackForwardList();
          if ((webHistory?.currentIndex ?? 0) <= 1) {
            return true;
          }
          await webViewController?.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("InAppWebView test"),
          leading: showBackButton
              ? BackButton(
                  onPressed: () {
                    webViewController?.goBack();
                  },
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              SearchField(
                urlController: urlController,
                webViewController: webViewController,
              ),
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      key: webViewKey,
                      /*initialUrlRequest:
                          URLRequest(url: Uri.parse("https://inappwebview.dev/"),
                      ),*/
                      // Loads html
                      // but first page does not count in the history, better use an external page
                      initialData: InAppWebViewInitialData(
                        data: '<html>'
                            '<head>'
                            '<meta name="viewport" content="initial-scale=1.0" />'
                            '</head>'
                            '<button onclick=history.back()">history.back()</button>'
                            '<button onclick="location.href = \'https://www.google.com\'">navigate out</button>'
                            '<a href="https://www.google.com">navigate out</a>'
                            '</html>',
                      ),
                      initialOptions: options,
                      pullToRefreshController: pullToRefreshController,
                      onWebViewCreated: (controller) {
                        webViewController = controller;
                      },
                      onLoadStart: (controller, url) {
                        setState(() async {
                          this.url = url.toString();
                          urlController.text = this.url;

                          //
                          showBackButton = await controller.canGoBack();
                        });
                      },
                      androidOnPermissionRequest:
                          (controller, origin, resources) async {
                        return PermissionRequestResponse(
                            resources: resources,
                            action: PermissionRequestResponseAction.GRANT);
                      },
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        /*var uri = navigationAction.request.url!;
                        if (![
                          "http",
                          "https",
                          "file",
                          "chrome",
                          "data",
                          "javascript",
                          "about",
                          // get the list of supported ones from info.plist
                        ].contains(uri.scheme)) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            // Launch the App
                            await launchUrl(uri);
                            // and cancel the request
                            return NavigationActionPolicy.CANCEL;
                          }
                        }
                        */
                        return NavigationActionPolicy.ALLOW;
                      },
                      onLoadStop: (controller, url) async {
                        pullToRefreshController.endRefreshing();
                        setState(() {
                          this.url = url.toString();
                          urlController.text = this.url;
                        });
                      },
                      onLoadError: (controller, url, code, message) {
                        pullToRefreshController.endRefreshing();
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          pullToRefreshController.endRefreshing();
                        }
                        setState(() {
                          this.progress = progress / 100;
                          urlController.text = url;
                        });
                      },
                      onUpdateVisitedHistory:
                          (controller, url, androidIsReload) {
                        setState(() async {
                          this.url = url.toString();
                          urlController.text = this.url;

                          //
                          showBackButton = await controller.canGoBack();
                        });
                      },
                      onConsoleMessage: (controller, consoleMessage) {
                        debugPrint(consoleMessage.message);
                      },
                    ),
                    progress < 1.0
                        ? LinearProgressIndicator(value: progress)
                        : Container(),
                  ],
                ),
              ),
              /*ButtonBar(
                alignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    child: const Icon(Icons.arrow_back),
                    onPressed: () {
                      webViewController?.goBack();
                    },
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
              ),*/
            ],
          ),
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    Key? key,
    required this.urlController,
    required this.webViewController,
  }) : super(key: key);

  final TextEditingController urlController;
  final InAppWebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
      controller: urlController,
      keyboardType: TextInputType.url,
      onSubmitted: (value) {
        var url = Uri.parse(value);
        if (url.scheme.isEmpty) {
          url = Uri.parse("https://www.google.com/search?q=$value");
        }
        webViewController?.loadUrl(urlRequest: URLRequest(url: url));
      },
    );
  }
}
