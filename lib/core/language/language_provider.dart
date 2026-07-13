import 'package:flutter/foundation.dart';

class LanguageProvider extends ChangeNotifier {
  bool isEnglish = false;

  void setEnglish(bool value) {
    if (isEnglish == value) return;
    isEnglish = value;
    notifyListeners();
  }

  String t(String ko, String en) => isEnglish ? en : ko;
}
