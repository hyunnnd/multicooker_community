class RecipeImageAssets {
  static const _base = 'https://images.unsplash.com/photo-';
  static const _query = '?w=800&h=520&fit=crop&auto=format';

  // 아래 URL은 사용자가 제공한 Figma/React zip의 App.tsx IMGS 상수와 동일한 원본 이미지 경로입니다.
  static const pork = '${_base}1548150914-c9f19106dbf6$_query';
  static const pork2 = '${_base}1550388342-b3fd986e4e67$_query';
  static const egg = '${_base}1590301157890-4810ed352733$_query';
  static const rice = '${_base}1706513043845-afb903a8c4c5$_query';
  static const shrimp = '${_base}1625943553852-781c6dd46faa$_query';
  static const shrimp2 = '${_base}1633504581786-316c8002b1b9$_query';
  static const dakgalbi = '${_base}1683225757624-86943fb48966$_query';
  static const steak = '${_base}1565299715199-866c917206bb$_query';
  static const risotto = '${_base}1595579547936-c3a0e6c171fc$_query';
  static const vegetables = '${_base}1677751632736-f0e9800186d2$_query';
  static const friedRice = '${_base}1484154218962-a197022b5858$_query';
  static const prep = '${_base}1690983323544-026a23725551$_query';
  static const toast = '${_base}1533089860892-a7c6f0a88666$_query';
  static const placeholder = '${_base}1484154218962-a197022b5858$_query';

  static String fallbackForTitle(String title) {
    final normalized = title.replaceAll(' ', '').toLowerCase();
    if (normalized.contains('밥') || normalized.contains('솥밥') || normalized.contains('rice')) return rice;
    if (normalized.contains('계란') || normalized.contains('달걀') || normalized.contains('egg')) return egg;
    if (normalized.contains('삼겹') || normalized.contains('고기') || normalized.contains('수육') || normalized.contains('갈비') || normalized.contains('pork')) return pork;
    if (normalized.contains('채소') || normalized.contains('야채') || normalized.contains('vegetable')) return vegetables;
    if (normalized.contains('새우') || normalized.contains('shrimp')) return shrimp;
    if (normalized.contains('닭갈비') || normalized.contains('닭') || normalized.contains('chicken')) return dakgalbi;
    if (normalized.contains('리조또') || normalized.contains('risotto')) return risotto;
    if (normalized.contains('볶음밥') || normalized.contains('friedrice')) return friedRice;
    if (normalized.contains('스테이크') || normalized.contains('steak')) return steak;
    return placeholder;
  }

  static String resolve(String title, String? thumbnailUrl) {
    final value = thumbnailUrl?.trim();
    if (value != null && value.isNotEmpty) {
      if (value.startsWith('assets/images/')) return fallbackForTitle(title);
      return value;
    }
    return fallbackForTitle(title);
  }
}
