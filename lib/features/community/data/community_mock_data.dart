import 'models/community_models.dart';

const popularThreshold = 100;

const communityPosts = <CommunityPost>[
  CommunityPost(
    id: 1,
    category: PostCategory.qa,
    username: '쿠커초보',
    avatarColor: 0xFF4A90D9,
    timeAgo: '10분 전',
    title: '압력 조리 후 밥이 너무 무른 것 같아요',
    content:
        '멀티쿠커로 처음 밥을 지었는데 너무 질어요. 물 비율을 어떻게 해야 할까요? 쌀 2컵에 물 몇 컵 넣으셨나요? 설명서엔 1:1이라고 나와 있는데 먹어보니까 너무 질어서요. 혹시 쌀 종류에 따라 다른가요?',
    likes: 8,
    comments: [
      CommunityComment(
        id: 1,
        username: '요리고수',
        avatarColor: 0xFF4CAF50,
        content: '쌀 1컵에 물 0.8컵으로 맞춰보세요! 처음엔 살짝 적게 넣는 게 나아요.',
        timeAgo: '5분 전',
        likes: 4,
        replies: [
          CommunityReply(
            id: 101,
            username: '쿠커초보',
            avatarColor: 0xFF4A90D9,
            content: '감사해요! 내일 다시 해볼게요 ㅎㅎ',
            timeAgo: '2분 전',
            likes: 1,
          ),
        ],
      ),
      CommunityComment(
        id: 2,
        username: '주부9단',
        avatarColor: 0xFFE91E63,
        content: '저도 처음에 그랬어요. 물을 평소보다 20% 줄이면 딱 좋더라고요!',
        timeAgo: '3분 전',
        likes: 2,
        replies: [],
      ),
    ],
    tags: ['밥짓기', '압력조리'],
    activity: ActivitySet(
      d3: ActivityWindow(likes: 4, comments: 3),
      d6: ActivityWindow(likes: 6, comments: 4),
      d9: ActivityWindow(likes: 8, comments: 5),
      d12: ActivityWindow(likes: 8, comments: 5),
    ),
  ),
  CommunityPost(
    id: 2,
    category: PostCategory.free,
    username: '나',
    avatarColor: 0xFFFF8C42,
    timeAgo: '32분 전',
    title: '감자 수육할 때 이 팁 쓰면 완전 부드러워요!',
    content:
        '감자를 먼저 30분 찌고 나서 수육을 같이 넣으면 훨씬 부드럽고 맛이 배요. 마늘이랑 된장 조금 추가하면 국물이 진해져요. 오늘 두 번째로 만들어봤는데 역시 맛있네요. 여러분도 꼭 해보세요! 멀티쿠커 없인 못 살겠어요 이제.',
    likes: 147,
    comments: [
      CommunityComment(
        id: 3,
        username: '홈쿡러버',
        avatarColor: 0xFF2196F3,
        content: '오 이거 진짜 꿀팁이네요! 내일 해볼게요 ㅎㅎ',
        timeAgo: '20분 전',
        likes: 7,
        replies: [
          CommunityReply(
            id: 201,
            username: '나',
            avatarColor: 0xFFFF8C42,
            content: '꼭 해보세요! 맛있을 거예요 ㅎㅎ',
            timeAgo: '18분 전',
            likes: 3,
          ),
        ],
      ),
      CommunityComment(
        id: 4,
        username: '쿠커초보',
        avatarColor: 0xFF4A90D9,
        content: '감자 크기는 어떻게 자르셨어요?',
        timeAgo: '15분 전',
        likes: 1,
        replies: [
          CommunityReply(
            id: 202,
            username: '나',
            avatarColor: 0xFFFF8C42,
            content: '4등분 정도로 큼직하게 자르시면 돼요~',
            timeAgo: '13분 전',
            likes: 5,
          ),
        ],
      ),
      CommunityComment(
        id: 5,
        username: '맛집탐방',
        avatarColor: 0xFF9C27B0,
        content: '저도 같은 방법으로 성공했어요! 진짜 부드럽더라고요.',
        timeAgo: '10분 전',
        likes: 8,
        replies: [],
      ),
    ],
    imageUrl:
        'https://images.unsplash.com/photo-1445979323117-80453f573b71?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=800',
    tags: ['감자수육', '꿀팁'],
    activity: ActivitySet(
      d3: ActivityWindow(likes: 0, comments: 0),
      d6: ActivityWindow(likes: 20, comments: 8),
      d9: ActivityWindow(likes: 30, comments: 12),
      d12: ActivityWindow(likes: 35, comments: 13),
    ),
  ),
  CommunityPost(
    id: 3,
    category: PostCategory.free,
    username: '홈쿡러버',
    avatarColor: 0xFF2196F3,
    timeAgo: '2시간 전',
    title: '오늘 멀티쿠커로 만든 점심 인증~',
    content:
        '고구마 찜이랑 된장찌개 동시에 완성! 멀티쿠커 진짜 신세계예요. 시간도 절약되고 맛도 훨씬 좋네요. 혼자 살면서 이렇게 간단하게 해 먹을 수 있다는 게 너무 좋아요. 앞으로 자주 올릴게요!',
    likes: 234,
    comments: [
      CommunityComment(
        id: 6,
        username: '주부9단',
        avatarColor: 0xFFE91E63,
        content: '와 예쁘게 차려놓으셨네요! 부럽다~',
        timeAgo: '1시간 전',
        likes: 9,
        replies: [],
      ),
      CommunityComment(
        id: 7,
        username: '맛집탐방',
        avatarColor: 0xFF9C27B0,
        content: '된장찌개 레시피도 올려주세요!',
        timeAgo: '1시간 전',
        likes: 6,
        replies: [
          CommunityReply(
            id: 301,
            username: '홈쿡러버',
            avatarColor: 0xFF2196F3,
            content: '다음에 올릴게요 ㅎㅎ 된장은 진짜 간단해요!',
            timeAgo: '50분 전',
            likes: 4,
          ),
        ],
      ),
    ],
    imageUrl:
        'https://images.unsplash.com/photo-1590301157890-4810ed352733?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=800',
    tags: ['오늘점심', '인증'],
    activity: ActivitySet(
      d3: ActivityWindow(likes: 52, comments: 14),
      d6: ActivityWindow(likes: 55, comments: 15),
      d9: ActivityWindow(likes: 55, comments: 15),
      d12: ActivityWindow(likes: 55, comments: 15),
    ),
  ),
  CommunityPost(
    id: 4,
    category: PostCategory.qa,
    username: '새내기쿠커',
    avatarColor: 0xFFFF5722,
    timeAgo: '3시간 전',
    title: '찜 기능이랑 압력 기능 차이가 뭔가요?',
    content:
        '설명서를 읽었는데 잘 이해가 안 가요. 고기 요리할 때 어떤 기능을 써야 더 맛있게 나오나요? 닭이랑 돼지고기 요리를 주로 하는데 추천 기능 알려주세요! 초보라서 잘 모르겠어요.',
    likes: 15,
    comments: [
      CommunityComment(
        id: 8,
        username: '요리고수',
        avatarColor: 0xFF4CAF50,
        content: '찜은 수분으로 익히고, 압력은 고압으로 빠르게 익혀요. 고기는 압력이 훨씬 부드럽게 나와요!',
        timeAgo: '2시간 전',
        likes: 18,
        replies: [
          CommunityReply(
            id: 401,
            username: '새내기쿠커',
            avatarColor: 0xFFFF5722,
            content: '좋은 정보 감사합니다!',
            timeAgo: '1시간 전',
            likes: 2,
          ),
        ],
      ),
    ],
    tags: ['기능질문', '초보'],
    activity: ActivitySet(
      d3: ActivityWindow(likes: 8, comments: 5),
      d6: ActivityWindow(likes: 10, comments: 6),
      d9: ActivityWindow(likes: 12, comments: 7),
      d12: ActivityWindow(likes: 12, comments: 7),
    ),
  ),
  CommunityPost(
    id: 5,
    category: PostCategory.free,
    username: '쿠커매니아',
    avatarColor: 0xFF795548,
    timeAgo: '6시간 전',
    title: '멀티쿠커로 요거트 만들기 성공했어요!',
    content:
        '유산균 발효 기능 있는 분들 꼭 해보세요. 시판 요거트보다 훨씬 맛있고 건강해요. 유리병에 담아서 냉장 보관하면 일주일 OK. 처음엔 어렵게 느껴졌는데 해보니까 너무 간단했어요. 다음엔 그릭 요거트도 도전해볼 예정입니다!',
    likes: 178,
    comments: [
      CommunityComment(
        id: 9,
        username: '건강러버',
        avatarColor: 0xFF8BC34A,
        content: '어떤 균 쓰셨나요? 저도 해보고 싶어요!',
        timeAgo: '5시간 전',
        likes: 8,
        replies: [
          CommunityReply(
            id: 501,
            username: '쿠커매니아',
            avatarColor: 0xFF795548,
            content: '시판 요거트를 스타터로 쓰면 돼요! 플레인으로요.',
            timeAgo: '4시간 전',
            likes: 11,
          ),
        ],
      ),
    ],
    tags: ['요거트', '발효', '건강'],
    activity: ActivitySet(
      d3: ActivityWindow(likes: 0, comments: 0),
      d6: ActivityWindow(likes: 0, comments: 0),
      d9: ActivityWindow(likes: 18, comments: 4),
      d12: ActivityWindow(likes: 22, comments: 5),
    ),
  ),
  CommunityPost(
    id: 6,
    category: PostCategory.free,
    username: '요리고수',
    avatarColor: 0xFF4CAF50,
    timeAgo: '8시간 전',
    title: '멀티쿠커 사골 육수 최고예요',
    content:
        '사골 육수를 보통 4-5시간 끓이는데 멀티쿠커 압력 기능 쓰면 1시간 30분 만에 뽀얀 육수 완성! 전기세도 훨씬 절약돼요. 국물이 정말 진하고 맛있어요. 시간이 단축되니까 평일에도 도전 가능해요!',
    likes: 312,
    comments: [
      CommunityComment(
        id: 10,
        username: '주부9단',
        avatarColor: 0xFFE91E63,
        content: '저도 이거 해봤는데 진짜 신세계였어요!',
        timeAgo: '7시간 전',
        likes: 22,
        replies: [],
      ),
      CommunityComment(
        id: 11,
        username: '홈쿡러버',
        avatarColor: 0xFF2196F3,
        content: '시간을 조금 더 늘리니 훨씬 맛있었어요.',
        timeAgo: '6시간 전',
        likes: 14,
        replies: [],
      ),
    ],
    imageUrl:
        'https://images.unsplash.com/photo-1635363638580-c2809d049eee?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=800',
    tags: ['사골육수', '압력조리'],
    activity: ActivitySet(
      d3: ActivityWindow(likes: 0, comments: 0),
      d6: ActivityWindow(likes: 5, comments: 2),
      d9: ActivityWindow(likes: 8, comments: 3),
      d12: ActivityWindow(likes: 10, comments: 4),
    ),
  ),
  CommunityPost(
    id: 7,
    category: PostCategory.qa,
    username: '주방초보',
    avatarColor: 0xFF607D8B,
    timeAgo: '1일 전',
    title: '보온 기능 얼마나 오래 쓸 수 있나요?',
    content:
        '밥을 해놓고 나중에 먹으려고 하는데 보온 기능이 몇 시간까지 괜찮은지 궁금해요. 너무 오래 두면 밥이 상하는 건지도요.',
    likes: 23,
    comments: [
      CommunityComment(
        id: 12,
        username: '요리고수',
        avatarColor: 0xFF4CAF50,
        content: '보통 12시간까지는 괜찮아요. 그 이상은 맛이 변할 수 있어요.',
        timeAgo: '23시간 전',
        likes: 16,
        replies: [],
      ),
    ],
    tags: ['보온기능', '밥'],
    activity: ActivitySet(
      d3: ActivityWindow(likes: 0, comments: 0),
      d6: ActivityWindow(likes: 0, comments: 0),
      d9: ActivityWindow(likes: 3, comments: 1),
      d12: ActivityWindow(likes: 5, comments: 2),
    ),
  ),
  CommunityPost(
    id: 8,
    category: PostCategory.free,
    username: '맛집탐방',
    avatarColor: 0xFF9C27B0,
    timeAgo: '1일 전',
    title: '삼겹살 구이 집에서도 식당 맛 가능해요',
    content:
        '멀티쿠커 구이 기능 + 뚜껑 열고 강불 모드 조합 써보셨나요? 겉은 바삭 속은 촉촉하게 나와요. 마지막에 불 세게 해서 마이야르 반응 일으키는 게 핵심! 가족들이 엄지척 했어요.',
    likes: 156,
    comments: [
      CommunityComment(
        id: 13,
        username: '홈쿡러버',
        avatarColor: 0xFF2196F3,
        content: '오 이렇게 하는 방법이 있었군요! 따라해볼게요.',
        timeAgo: '20시간 전',
        likes: 19,
        replies: [],
      ),
    ],
    imageUrl:
        'https://images.unsplash.com/photo-1548150914-c9f19106dbf6?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=800',
    tags: ['삼겹살', '구이'],
    activity: ActivitySet(
      d3: ActivityWindow(likes: 25, comments: 9),
      d6: ActivityWindow(likes: 28, comments: 10),
      d9: ActivityWindow(likes: 30, comments: 11),
      d12: ActivityWindow(likes: 30, comments: 11),
    ),
  ),
];

const communityReviews = <CommunityReview>[
  CommunityReview(
    id: 1,
    username: '맛집탐방',
    avatarColor: 0xFF9C27B0,
    recipeTitle: '감자수육 삼겹살 구이',
    recipeId: 'pork',
    recipeImage:
        'https://images.unsplash.com/photo-1548150914-c9f19106dbf6?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 5,
    content:
        '진짜 맛있어요! 감자가 속까지 잘 익고 삼겹살도 바삭하게 잘 구워졌어요. 온 가족이 맛있다고 해서 뿌듯했어요. 조리 시간도 생각보다 짧아서 놀랐어요.',
    date: '2026.06.28',
    likes: 23,
    commentCount: 5,
  ),
  CommunityReview(
    id: 2,
    username: '요리고수',
    avatarColor: 0xFF4CAF50,
    recipeTitle: '감자수육 삼겹살 구이',
    recipeId: 'pork',
    recipeImage:
        'https://images.unsplash.com/photo-1550388342-b3fd986e4e67?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 5,
    content:
        '멀티쿠커로 이렇게 맛있는 요리가 된다는 게 신기해요. 레시피 설명이 너무 친절하고 따라하기 쉬웠어요! 자주 해먹을 것 같아요.',
    date: '2026.06.25',
    likes: 17,
    commentCount: 3,
  ),
  CommunityReview(
    id: 3,
    username: '홈쿡러버',
    avatarColor: 0xFF2196F3,
    recipeTitle: '압력 닭볶음탕',
    recipeId: 'dakgalbi',
    recipeImage:
        'https://images.unsplash.com/photo-1635363638580-c2809d049eee?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 5,
    content:
        '사실 기대 안 했는데 진짜 식당에서 먹는 것 같은 맛이 나왔어요. 남편이 세 그릇 먹었어요. 강력 추천합니다!',
    date: '2026.06.22',
    likes: 31,
    commentCount: 7,
  ),
  CommunityReview(
    id: 4,
    username: '주부9단',
    avatarColor: 0xFFE91E63,
    recipeTitle: '압력 닭볶음탕',
    recipeId: 'dakgalbi',
    recipeImage:
        'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 4,
    content:
        '맛은 정말 좋아요. 닭이 완전 부드럽고 국물이 진해요. 근데 조리 시간이 조금 더 필요한 것 같았어요. 다음엔 5분 더 해볼게요.',
    date: '2026.06.19',
    likes: 12,
    commentCount: 4,
  ),
  CommunityReview(
    id: 5,
    username: '쿠커매니아',
    avatarColor: 0xFF795548,
    recipeTitle: '된장찌개 & 고구마 찜',
    recipeId: 'rice',
    recipeImage:
        'https://images.unsplash.com/photo-1590301157890-4810ed352733?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 5,
    content:
        '두 가지를 동시에 만들 수 있다는 게 진짜 편리해요! 맛도 훌륭하고 시간도 절약되고. 이 레시피 덕분에 평일 저녁이 행복해졌어요.',
    date: '2026.06.16',
    likes: 28,
    commentCount: 6,
  ),
];

const communityNotices = <CommunityNotice>[
  CommunityNotice(
    id: 1,
    title: '멀티쿠커 커뮤니티 이용 안내',
    date: '2026.07.01',
    summary: '커뮤니티를 더욱 즐겁게 이용하기 위한 기본 안내입니다.',
    content: '''안녕하세요, 멀티쿠커 커뮤니티입니다 :)

모든 회원분들이 즐겁게 이용하실 수 있도록 아래 이용 안내를 꼭 읽어주세요.

■ 게시글 작성 시
• 요리와 관련된 내용을 자유롭게 작성해주세요.
• 타인을 비방하거나 불쾌감을 주는 게시글은 삭제될 수 있습니다.
• 광고성 게시글은 금지됩니다.

■ 댓글 작성 시
• 서로 존중하는 댓글 문화를 만들어주세요.
• 질문에는 친절하게 답변해주세요.

■ 후기 작성 시
• 레시피 상세 화면에서 직접 별점과 후기를 남길 수 있습니다.
• 솔직한 후기 작성을 권장드립니다.

커뮤니티를 사랑해주셔서 감사합니다 ♥''',
    important: true,
  ),
  CommunityNotice(
    id: 2,
    title: '레시피 등록 가이드라인 업데이트',
    date: '2026.06.20',
    summary: '더 좋은 레시피 등록을 위한 가이드라인이 업데이트되었습니다.',
    content: '''레시피 등록 가이드라인이 업데이트되었습니다.

■ 주요 변경사항
• 사진 첨부 시 음식이 잘 보이는 밝은 사진을 권장합니다.
• 재료는 분량을 정확하게 기입해주세요.
• 조리 순서는 단계별로 명확하게 작성해주세요.
• 멀티쿠커 기능(압력, 찜, 구이 등)을 명시해주시면 더 좋아요.

자세한 내용은 레시피 작성 화면에서 확인하실 수 있습니다.''',
    important: true,
  ),
  CommunityNotice(
    id: 3,
    title: '6월 우수 레시피 이벤트 결과 발표',
    date: '2026.06.10',
    summary: '6월 이벤트에 참여해주신 모든 분들께 감사드립니다.',
    content: '''6월 우수 레시피 이벤트에 많은 참여 감사드립니다!

■ 최우수 레시피
• 감자수육 삼겹살 구이 - 요리고수님

■ 우수 레시피
• 압력 닭볶음탕 - 주부9단님
• 멀티쿠커 요거트 - 쿠커매니아님

당첨자 분들께는 개별 연락 드리겠습니다. 감사합니다!''',
    important: false,
  ),
  CommunityNotice(
    id: 4,
    title: '서비스 점검 안내 (완료)',
    date: '2026.05.25',
    summary: '서비스 점검이 완료되었습니다. 이용에 불편을 드려 죄송합니다.',
    content: '''안녕하세요.

5월 25일 오전 2시부터 4시까지 서비스 정기 점검이 진행되었습니다.

점검이 정상적으로 완료되어 서비스를 이용하실 수 있습니다.

이용에 불편을 드려 죄송합니다. 감사합니다.''',
    important: false,
  ),
  CommunityNotice(
    id: 5,
    title: '커뮤니티 기능 업데이트 안내',
    date: '2026.05.10',
    summary: '커뮤니티에 새로운 기능이 추가되었습니다.',
    content: '''커뮤니티에 새로운 기능이 추가되었습니다!

■ 추가된 기능
• 댓글 답글 기능
• 인기 게시글 자동 분류 (좋아요 100개 이상)
• 레시피 상세 화면에서 후기와 별점 확인

앞으로도 더 편리한 커뮤니티를 만들어가겠습니다. 감사합니다!''',
    important: false,
  ),
];

const communityNotifications = <CommunityNotification>[
  CommunityNotification(
    id: 1,
    type: NotificationType.comment,
    fromUser: '홈쿡러버',
    avatarColor: 0xFF2196F3,
    postTitle: '감자 수육할 때 이 팁 쓰면 완전 부드러워요!',
    postId: 2,
    timeAgo: '20분 전',
    read: false,
  ),
  CommunityNotification(
    id: 2,
    type: NotificationType.comment,
    fromUser: '쿠커초보',
    avatarColor: 0xFF4A90D9,
    postTitle: '감자 수육할 때 이 팁 쓰면 완전 부드러워요!',
    postId: 2,
    timeAgo: '15분 전',
    read: false,
  ),
  CommunityNotification(
    id: 3,
    type: NotificationType.reply,
    fromUser: '홈쿡러버',
    avatarColor: 0xFF2196F3,
    postTitle: '감자수육 삼겹살 구이 레시피 진짜 대박이에요',
    postId: 3,
    timeAgo: '45분 전',
    read: true,
  ),
];
