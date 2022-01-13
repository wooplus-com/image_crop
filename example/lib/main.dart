import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_crop/image_crop.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(new MyApp(
    decorator: AssetImage('assets/image_photo_person.png'),
  ));
}

class MyApp extends StatefulWidget {
  final ImageProvider decorator;

  const MyApp({
    Key key,
    this.decorator,
  }) : super(key: key);

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final cropKey = GlobalKey<CropState>();
  File _file;
  File _sample;
  File _lastCropped;

  ui.Image _decoratorImage;
  ImageStream _decoratorImageStream;
  ImageStreamListener _decoratorImageListener;

  @override
  void dispose() {
    super.dispose();
    _file?.delete();
    _sample?.delete();
    _lastCropped?.delete();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SafeArea(
        child: Container(
          color: Colors.lightBlue,
          padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
          child: _sample == null ? _buildOpeningImage() : _buildCroppingImage(),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    test();
  }

  void test() async {
    await Future.delayed(Duration(seconds: 1));
    _getDecoratorImage();

  }

  @override
  void didUpdateWidget(MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _getDecoratorImage();
  }

  Widget _buildOpeningImage() {
    return Center(child: _buildOpenImage());
  }

  Widget _buildCroppingImage() {
    return Column(
      children: <Widget>[
        Expanded(
          child: Crop.file(
            _sample,
            key: cropKey,
            aspectRatio: 1.5,
            showGrid: false,
            enableAdjustCropWindow: false,
            onCalculateDefaultArea: _onCalculateDefaultArea,
            onAfterPrint: _onAfterPaint,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 20.0),
          alignment: AlignmentDirectional.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              TextButton(
                child: Text(
                  'Crop Image',
                  style: Theme.of(context)
                      .textTheme
                      .button
                      .copyWith(color: Colors.white),
                ),
                onPressed: () => _cropImage(),
              ),
              _buildOpenImage(),
            ],
          ),
        )
      ],
    );
  }

  Rect _onCalculateDefaultArea(Rect area, Size size) {
    var padding = EdgeInsets.all(20);
    var result = Rect.fromLTWH(
        area.left + padding.left / size.width,
        area.top + padding.top / size.height,
        area.width - (padding.left + padding.right) / size.width,
        area.height - (padding.top + padding.bottom) / size.height);
    return result;
  }

  void _onAfterPaint(Canvas canvas, Paint paint, Rect boundaries) {
    if (_decoratorImage == null) {
      return;
    }
    ui.Image image = _decoratorImage;
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        boundaries,
        paint);
  }

  Widget _buildOpenImage() {
    return TextButton(
      child: Text(
        'Open Image',
        style: Theme.of(context).textTheme.button.copyWith(color: Colors.white),
      ),
      onPressed: () => _openImage(),
    );
  }

  Future<void> _openImage() async {
    final pickedFile =
        await ImagePicker().getImage(source: ImageSource.gallery);
    final file = File(pickedFile.path);
    final sample = await ImageCrop.sampleImage(
      file: file,
      preferredSize: context.size.longestSide.ceil(),
    );

    _sample?.delete();
    _file?.delete();

    setState(() {
      _sample = sample;
      _file = file;
    });
  }

  Future<void> _cropImage() async {
    final scale = cropKey.currentState.scale;
    final area = cropKey.currentState.area;
    if (area == null) {
      // cannot crop, widget is not setup
      return;
    }

    // scale up to use maximum possible number of pixels
    // this will sample image in higher resolution to make cropped image larger
    final sample = await ImageCrop.sampleImage(
      file: _file,
      preferredSize: (2000 / scale).round(),
    );

    final file = await ImageCrop.cropImage(
      file: sample,
      area: area,
    );

    sample.delete();

    _lastCropped?.delete();
    _lastCropped = file;

    debugPrint('$file');
  }

  void _getDecoratorImage() {
    if (widget.decorator == null) return;

    final oldImageStream = _decoratorImageStream;
    _decoratorImageStream =
        widget.decorator.resolve(createLocalImageConfiguration(context));
    if (_decoratorImageStream.key != oldImageStream?.key) {
      oldImageStream
          ?.removeListener(ImageStreamListener(_updateDecoratorImage));
      _decoratorImageStream
          .addListener(ImageStreamListener(_updateDecoratorImage));
    }
  }

  _updateDecoratorImage(ImageInfo imageInfo, bool synchronousCall) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        setState(() {
          _decoratorImage = imageInfo.image;
        });
      }
    });
  }
}
