import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vidiyo/API.dart';
import 'package:vidiyo/constants.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});
  final TextEditingController urlController = TextEditingController();
  RxBool isLoading = false.obs;
  RxList resolutionList = [].obs;
  RxString title = ''.obs;
  RxString thumbnailUrl = ''.obs;
  RxDouble progress = 0.0.obs;
  final String storagePath = '/storage/emulated/0/Download';

  checkInternetConnection(context) async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'No Internet Connection!',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        elevation: 10,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(5),
      ));
      return false;
    }
  }

  getInfo(String youtubeURL, context) async {
    bool isConnected = await checkInternetConnection(context);

    if (youtubeURL.isEmpty || !isConnected) {
      return;
    }
    isLoading.value = true;
    var url = Uri.parse(API + youtubeURL);

    try {
      var response = await http.get(url);

      if (response.statusCode == 200) {
        Map body = json.decode(response.body);
        title.value = body['title'];
        thumbnailUrl.value = body['thumbnailUrl'];
        resolutionList.value = body['formats'];
        resolutionList.sort((a, b) => a['size'].compareTo(b['size']));
      }
    } catch (e) {
      isLoading.value = false;
      print(e);
    } finally {
      isLoading.value = false;
    }
  }

  String getFileName(String fileName) {
    RegExp invalidChars = RegExp(r'[\/:*?"<>|]');
    String sanitizedFileName = fileName.replaceAll(invalidChars, '_');
    return sanitizedFileName;
  }

  downloadVideo(dynamic video, context) async {
    bool isConnected = await checkInternetConnection(context);

    if (!isConnected) {
      return;
    }

    final snackBar = SnackBar(
      content: Text(
        'Download Successfull!',
        style: TextStyle(
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.green,
      elevation: 10,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(5),
    );

    CancelToken cancelToken = CancelToken();

    final dio = Dio();
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    var url = video['url'];

    final savePath =
        '${storagePath}/${getFileName(title.value)}.${video['extension']}';

    Get.defaultDialog(
      barrierDismissible: false,
      title: 'Downloading',
      content: WillPopScope(
        onWillPop: () async => false,
        child: Obx(
          () => LinearPercentIndicator(
            lineHeight: 20.0,
            percent: progress.value.round() / 100,
            center: Text(progress.value.round().toString() + '%'),
            barRadius: Radius.circular(10),
            progressColor: primary,
          ),
        ),
      ),
      cancel: ElevatedButton(
        onPressed: () {
          Get.back();
          cancelToken.cancel();
        },
        child: Text('Cancel'),
      ),
    );

    await dio.download(url, savePath, onReceiveProgress: (received, total) {
      if (total != -1) {
        progress.value = (received / total * 100);
      }
    }).then((value) => {
          ScaffoldMessenger.of(context).showSnackBar(snackBar),
          print('File downloaded to: ${savePath}'),
          Get.back(),
        });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: secondary,
      child: Stack(
        children: [
          SvgPicture.asset(
            'assets/wave-haikei.svg',
            fit: BoxFit.cover,
          ),
          SingleChildScrollView(
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  // height: 60,
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: urlController,
                    style: TextStyle(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        splashRadius: 5,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.clear,
                          color: Color.fromARGB(255, 160, 160, 160),
                          size: 20,
                        ),
                        onPressed: () {
                          thumbnailUrl.value = '';
                          resolutionList.clear();
                          urlController.clear();
                        },
                      ),
                      hintText: 'Enter URL here',
                      hintStyle: TextStyle(
                        color: Colors.grey,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: primary,
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(
                            10.0,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: primary,
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(
                            10.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Obx(
                  () => SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                      ),
                      onPressed: () {
                        getInfo(urlController.text, context);
                      },
                      child: isLoading.value
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Download',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Obx(
                  () => resolutionList.length > 0
                      ? Column(
                          children: [
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 90, vertical: 20),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(thumbnailUrl.value)),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 10.0, sigmaY: 10.0),
                                  child: Container(
                                    // height: 400,
                                    color: Colors.white.withOpacity(0.1),
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: resolutionList.length,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              margin: EdgeInsets.only(
                                                bottom: 5,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    resolutionList[index]
                                                            ['qualityLabel'] +
                                                        'p',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 20,
                                                  ),
                                                  Text(
                                                    resolutionList[index]
                                                        ['size'],
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 20,
                                                  ),
                                                  OutlinedButton(
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      side: BorderSide(
                                                        color: Colors.green,
                                                      ),
                                                      foregroundColor:
                                                          Colors.green,
                                                    ),
                                                    child: Text('Download'),
                                                    onPressed: () async {
                                                      downloadVideo(
                                                          resolutionList[index],
                                                          context);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(),
                ),
                SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
