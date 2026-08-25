/// Кодировщик PNG на «сыром» RGBA — свой, а не из пакета.
///
/// Причина не в экономии зависимости, а в альфа-канале. `Image.toByteData`
/// умеет отдать PNG сама, но всегда с альфой, а App Store отклоняет иконку
/// с альфа-каналом — это старое и до сих пор живое правило. Здесь тип цвета
/// выбирается вызывающим: непрозрачные иконки уходят как truecolor (2),
/// слои адаптивной иконки — как truecolor+alpha (6).
///
/// zlib берётся из `dart:io`, CRC32 — двадцать строк ниже. Ничего больше
/// PNG не требует: одна IHDR, одна IDAT, одна IEND, фильтр 0 на каждой
/// строке.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Собирает PNG из RGBA-байтов (row-primary, straight alpha).
///
/// [opaque] выкидывает альфу и пишет тип цвета 2. Вызывающий отвечает за то,
/// что она действительно везде 255: молча срезанная полупрозрачность дала бы
/// картинку с чёрной каймой вместо ошибки.
Uint8List encodePng(
  int width,
  int height,
  Uint8List rgba, {
  required bool opaque,
}) {
  if (rgba.length != width * height * 4) {
    throw ArgumentError(
      'RGBA ожидается ${width * height * 4} байт, пришло ${rgba.length}',
    );
  }
  final channels = opaque ? 3 : 4;
  final raw = Uint8List(height * (1 + width * channels));
  var out = 0;
  var src = 0;
  for (var y = 0; y < height; y++) {
    raw[out++] = 0; // фильтр None: сжатие и так справляется на плашках
    for (var x = 0; x < width; x++) {
      raw[out++] = rgba[src];
      raw[out++] = rgba[src + 1];
      raw[out++] = rgba[src + 2];
      if (!opaque) raw[out++] = rgba[src + 3];
      src += 4;
    }
  }

  final header = Uint8List(13);
  final view = ByteData.view(header.buffer);
  view.setUint32(0, width);
  view.setUint32(4, height);
  header[8] = 8; // бит на канал
  header[9] = opaque ? 2 : 6; // truecolor / truecolor+alpha
  header[10] = 0; // deflate
  header[11] = 0; // фильтры adaptive
  header[12] = 0; // без чересстрочности

  final bytes = BytesBuilder();
  bytes.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _chunk(bytes, 'IHDR', header);
  _chunk(bytes, 'IDAT', Uint8List.fromList(ZLibCodec(level: 9).encode(raw)));
  _chunk(bytes, 'IEND', Uint8List(0));
  return bytes.toBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final name = Uint8List.fromList(ascii.encode(type));
  final length = ByteData(4)..setUint32(0, data.length);
  out.add(length.buffer.asUint8List());
  out.add(name);
  out.add(data);
  final crc = ByteData(4)..setUint32(0, _crc32([...name, ...data]));
  out.add(crc.buffer.asUint8List());
}

final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
