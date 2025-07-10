import 'dart:convert';
import 'dart:collection';
import 'package:flutter/foundation.dart'; // 导入 compute
import 'package:flutter/material.dart';

/// 一个简单的 LRU 缓存，用于存储已解码的图像字节。
///
/// 使用 [LinkedHashMap] 来维护访问顺序，确保最少使用的项目在需要时被逐出。
class _LruImageCache {
  final int capacity;
  final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();

  _LruImageCache(this.capacity);

  /// 从缓存中获取一个值，如果存在，则将其移到最近使用的位置。
  Uint8List? get(String key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to the end (most recently used)
    }
    return value;
  }

  /// 向缓存中添加一个值，如果超出容量，则删除最少使用的项。
  void set(String key, Uint8List value) {
    _cache[key] = value;
    if (_cache.length > capacity) {
      _cache.remove(_cache.keys.first); // Remove the least recently used
    }
  }
}

// 全局缓存实例，容量可以根据应用需求进行调整。
final _imageCache = _LruImageCache(100); // 缓存最多 100 张图片

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
  bool _wasInCache = false;

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
      _wasInCache = false; // 重置缓存状态
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

	   if (widget.base64String.isEmpty) {
	     return; // 如果字符串为空，则不执行任何操作
	   }

	   // 1. 尝试从缓存中获取
	   final cachedBytes = _imageCache.get(widget.base64String);
	   if (cachedBytes != null) {
	     if (mounted) {
	       setState(() {
	         _imageBytes = cachedBytes;
           _wasInCache = true; // 标记为来自缓存
	       });
	     }
	     return;
	   }

	   // 2. 如果缓存中没有，则在后台进行解码
	   compute(_decodeImageInBackground, widget.base64String).then((bytes) {
	     if (mounted) {
	       // 3. 将解码后的数据存入缓存并更新状态
	       _imageCache.set(widget.base64String, bytes);
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

    final imageWidget = _imageBytes != null
        ? Image.memory(
            _imageBytes!,
            key: ValueKey(widget.base64String), // 使用 base64String 作为 key
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            cacheWidth: widget.cacheWidth,
            cacheHeight: widget.cacheHeight,
            gaplessPlayback: true,
            errorBuilder: widget.errorBuilder,
          )
        : SizedBox(
            key: const ValueKey('placeholder'),
            width: widget.width,
            height: widget.height,
          );

    // 如果图片来自缓存，则直接显示，不加动画
    if (_wasInCache) {
      return imageWidget;
    }

    // 如果图片是新解码的，则使用淡入动画
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: imageWidget,
    );
	}
}