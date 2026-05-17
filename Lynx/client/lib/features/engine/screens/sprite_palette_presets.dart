import 'package:flutter/material.dart';

enum SpritePalettePreset { basic, db32, pico8 }

const List<Color> kSpritePaletteDb32 = <Color>[
  Color(0xFF000000), Color(0xFFbe4a2f), Color(0xFFd77643), Color(0xFFead4aa),
  Color(0xFFe4a672), Color(0xFFb86f50), Color(0xFF733e39), Color(0xFF3e2731),
  Color(0xFFa22633), Color(0xFFe43b44), Color(0xFFf77622), Color(0xFFfeae34),
  Color(0xFFfee761), Color(0xFF63c74d), Color(0xFF3e8948), Color(0xFF265c42),
  Color(0xFF193c3e), Color(0xFF124e89), Color(0xFF0099db), Color(0xFF2ce8f4),
  Color(0xFFffffff), Color(0xFFc0cbdc), Color(0xFF8b9bb4), Color(0xFF5a6988),
  Color(0xFF3a4466), Color(0xFF262b44), Color(0xFF181425), Color(0xFFff0044),
  Color(0xFF68386c), Color(0xFFb55088), Color(0xFFf6757a), Color(0xFFe8b796),
];

const List<Color> kSpritePalettePico8 = <Color>[
  Color(0xFF000000), Color(0xFF1D2B53), Color(0xFF7E2553), Color(0xFF008751),
  Color(0xFFAB5236), Color(0xFF5F574F), Color(0xFFC2C3C7), Color(0xFFEFFF1A),
  Color(0xFF00E436), Color(0xFF29ADFF), Color(0xFF83769C), Color(0xFFFF77A8),
  Color(0xFFFFCCAA), Color(0xFF742F29), Color(0xFF005784), Color(0xFFFFA300),
];

const List<Color> kSpritePaletteBasic = <Color>[
  Color(0xFFe53935),
  Color(0xFFfb8c00),
  Color(0xFFfdd835),
  Color(0xFF43a047),
  Color(0xFF1e88e5),
  Color(0xFF5e35b1),
  Color(0xFFffffff),
  Color(0xFF212121),
  Color(0xFF8d6e63),
  Color(0xFFec407a),
];

List<Color> colorsForSpritePalettePreset(SpritePalettePreset p) {
  switch (p) {
    case SpritePalettePreset.basic:
      return kSpritePaletteBasic;
    case SpritePalettePreset.db32:
      return kSpritePaletteDb32;
    case SpritePalettePreset.pico8:
      return kSpritePalettePico8;
  }
}

String labelForSpritePalettePreset(SpritePalettePreset p) {
  switch (p) {
    case SpritePalettePreset.basic:
      return 'Базовая';
    case SpritePalettePreset.db32:
      return 'DB32';
    case SpritePalettePreset.pico8:
      return 'PICO-8';
  }
}
