import 'dart:convert';
import 'package:flutter/foundation.dart'; // 导入 compute
import 'package:flutter/material.dart';

// 顶层函数，用于在后台 Isolate 中进行解码。
// 它必须是顶层函数或静态方法才能被 compute 调用。
Uint8List _decodeImageInBackground(String base64String) {
  return base64Decode(base64String);
}


/// 一个 StatefulWidget，用于解码 Base64 字符串并显示图片。
/// 它将解码后的字节缓存在其 State 中，并使用 compute 函数在后台 Isolate 中执行解码，
/// 以避免在列表拖动等操作中因解码阻塞 UI 线程而导致闪烁或卡顿。
class CachedImageFromBase64 extends StatefulWidget {
	final String base64String;
	final double? width;
	final double? height;
	final BoxFit? fit;
	final int? cacheWidth;
	final int? cacheHeight;
	final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

	const CachedImageFromBase64({
		super.key,
		required this.base64String,
		this.width,
		this.height,
		this.fit,
		this.cacheWidth,
		this.cacheHeight,
		this.errorBuilder,
	});

	@override
	State<CachedImageFromBase64> createState() => _CachedImageFromBase64State();
}

class _CachedImageFromBase64State extends State<CachedImageFromBase64> {
	Uint8List? _imageBytes;
	Object? _error;
  StackTrace? _stackTrace;

	@override
	void initState() {
		super.initState();
		_decodeImage();
	}

	@override
	void didUpdateWidget(CachedImageFromBase64 oldWidget) {
		super.didUpdateWidget(oldWidget);
		// 当 Base64 字符串发生变化时，才重新解码
		if (widget.base64String != oldWidget.base64String) {
			_decodeImage();
		}
	}

	void _decodeImage() {
    // 清除之前的状态，准备开始解码
    setState(() {
      _imageBytes = null;
      _error = null;
      _stackTrace = null;
    });

		if (widget.base64String.isNotEmpty) {
      compute(_decodeImageInBackground, widget.base64String).then((bytes) {
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
          });
        }
      }).catchError((e, s) {
        if (mounted) {
          setState(() {
            _error = e;
            _stackTrace = s;
          });
        }
      });
		}
	}

	@override
	Widget build(BuildContext context) {
		// 如果解码出错，并且提供了 errorBuilder，则使用它
		if (_error != null && widget.errorBuilder != null) {
			return widget.errorBuilder!(context, _error!, _stackTrace);
		}
		// 如果解码出错，但没有 errorBuilder，可以返回一个默认的错误占位符
		if (_error != null) {
			return const Icon(Icons.broken_image, color: Colors.grey);
		}

		// 如果正在解码 (_imageBytes 为 null 且没有错误)，可以显示一个加载指示器
		  if (_imageBytes == null) {
		    return Center(
		      child: SizedBox(
		        width: widget.width != null ? widget.width! * 0.5 : 20,
		        height: widget.height != null ? widget.height! * 0.5 : 20,
		        child: const CircularProgressIndicator(strokeWidth: 2.0),
		      ),
		    );
		  }

		// 成功解码，显示图片
		return Image.memory(
			_imageBytes!,
			width: widget.width,
			height: widget.height,
			fit: widget.fit,
			cacheWidth: widget.cacheWidth,
			cacheHeight: widget.cacheHeight,
			// gaplessPlayback: true 可在新旧图片切换时防止空白闪烁，对于列表平滑滚动很有帮助
			gaplessPlayback: true, 
			errorBuilder: widget.errorBuilder,
		);
	}
}