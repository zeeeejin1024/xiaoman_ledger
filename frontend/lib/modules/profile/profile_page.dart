import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/theme_reveal.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/modules/settings/settings_page.dart';
import 'package:xiaojia_ledger/modules/sync/sync_page.dart';
import 'package:xiaojia_ledger/modules/report/weekly_report_page.dart';
import 'package:xiaojia_ledger/modules/report/monthly_report_page.dart';
import 'package:xiaojia_ledger/core/china_regions.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _nickname = '';
  String _status = '';
  String? _avatarPath;
  String _username = '';
  bool _hasAvatar = false;
  final _themeSwatchKeys = List.generate(
    AppColorScheme.all.length,
    (_) => GlobalKey(),
  );
  int _themeRequest = 0;

  static const _presetStatuses = [
    '开心',
    '难过',
    '加油',
    '庆祝',
    '疲惫',
    '工作',
    '运动',
    '干饭',
    '音乐',
    '学习',
    '旅行',
    '省钱',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_avatar');
    bool hasAv = false;
    if (path != null) hasAv = await File(path).exists();
    if (mounted) {
      setState(() {
        _nickname =
            prefs.getString('profile_nickname') ??
            prefs.getString(AppConstants.usernameKey) ??
            '点击设置昵称';
        _username = prefs.getString(AppConstants.usernameKey) ?? '';
        _status = prefs.getString('profile_status') ?? '';
        _avatarPath = path;
        _hasAvatar = hasAv;
      });
    }
  }

  Future<void> _pickAvatar() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (xFile != null) {
      final dir = await getApplicationDocumentsDirectory();
      final saved = File('${dir.path}/avatar.png');
      await File(xFile.path).copy(saved.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_avatar', saved.path);
      setState(() {
        _avatarPath = saved.path;
        _hasAvatar = true;
      });
    }
  }

  Future<void> _editStatus() async {
    final ctrl = TextEditingController(text: _status);
    String temp = _status;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return StatefulBuilder(
            builder: (ctx, setInner) {
              return Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgSheet,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.gray,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '编辑状态',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        children: _presetStatuses.map((s) {
                          final sel = temp == s;
                          return Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                temp = s;
                                ctrl.text = s;
                                setInner(() {});
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.accent.withAlpha(40)
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: sel
                                      ? Border.all(
                                          color: AppColors.accent.withAlpha(
                                            120,
                                          ),
                                        )
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '自定义状态...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.card,
                          contentPadding: EdgeInsets.all(14),
                        ),
                        maxLength: 30,
                        onChanged: (_) => setInner(() {}),
                      ),
                    ),
                    SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            final text = ctrl.text.trim();
                            if (text.isNotEmpty) {
                              await prefs.setString('profile_status', text);
                            }
                            if (!mounted) return;
                            setState(() => _status = text);
                            Navigator.pop(context);
                          },
                          child: Text('保存'),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      ctrl.dispose();
    }
  }

  void _openPersonalInfo() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonalInfoSheet(
        nickname: _nickname,
        avatarPath: _avatarPath,
        onSaved: _loadProfile,
      ),
    );
  }

  Future<void> _changeScheme(int index) async {
    final request = ++_themeRequest;
    final s = AppColorScheme.all[index];
    final render = _themeSwatchKeys[index].currentContext?.findRenderObject();
    final origin = render is RenderBox && render.hasSize
        ? render.localToGlobal(render.size.center(Offset.zero))
        : const Offset(-1, -1);
    final saved = await ThemeReveal.change(context, s, origin);
    if (!saved &&
        mounted &&
        request == _themeRequest &&
        identical(AppColors.scheme, s)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配色已切换，但保存失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppThemedPage(builder: (context, _) => _buildPage(context));

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16),
          children: [
            SizedBox(height: 20),
            // ===== 头像区 =====
            GestureDetector(
              key: const ValueKey('profile-edit-hit-target'),
              behavior: HitTestBehavior.opaque,
              onTap: _openPersonalInfo,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 96),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _pickAvatar();
                      },
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightGray,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withAlpha(60),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: AppColors.gold.withAlpha(25),
                              blurRadius: 40,
                              offset: const Offset(0, 0),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.gold.withAlpha(100),
                            width: 2.5,
                          ),
                          image: _hasAvatar && _avatarPath != null
                              ? DecorationImage(
                                  image: FileImage(File(_avatarPath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _hasAvatar
                            ? null
                            : Icon(
                                Icons.person,
                                size: 36,
                                color: AppColors.gray,
                              ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nickname,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _username.isNotEmpty ? _username : '点击设置昵称',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.gray, size: 22),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // ===== 状态卡 =====
            PremiumCard(
              padding: EdgeInsets.zero,
              radius: 16,
              child: ListTile(
                leading: Text(
                  '状态',
                  style: TextStyle(fontSize: 16, color: AppColors.ink),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_status.isNotEmpty)
                      Text(
                        _status,
                        style: TextStyle(fontSize: 14, color: AppColors.gray),
                      ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.add_circle_outline,
                      color: AppColors.gray,
                      size: 20,
                    ),
                  ],
                ),
                onTap: _editStatus,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                minTileHeight: 56,
              ),
            ),
            SizedBox(height: 20),

            // ===== 功能菜单 =====
            PremiumCard(
              radius: 16,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _menuRow(
                    Icons.calendar_month_rounded,
                    '月度报告',
                    AppColors.sage,
                    () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MonthlyReportPage(),
                        ),
                      );
                    },
                  ),
                  const _MenuDivider(),
                  _menuRow(
                    Icons.auto_awesome_rounded,
                    '省钱周报',
                    AppColors.coral,
                    () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WeeklyReportPage(),
                        ),
                      );
                    },
                  ),
                  const _MenuDivider(),
                  _menuRow(Icons.sync_rounded, '账单同步', AppColors.info, () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SyncPage()),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(height: 20),

            // ===== 颜色切换 =====
            PremiumCard(
              radius: 16,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '主题配色',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: AppColorScheme.all.asMap().entries.map((e) {
                      final i = e.key;
                      final s = e.value;
                      final sel = i == AppColors.schemeIndex;
                      return Semantics(
                        key: ValueKey('theme-semantics-$i'),
                        label: '${s.name}主题',
                        button: true,
                        selected: sel,
                        child: GestureDetector(
                          key: ValueKey('theme-choice-$i'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _changeScheme(i);
                          },
                          child: Column(
                            children: [
                              Container(
                                key: _themeSwatchKeys[i],
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: s.brightness == Brightness.dark
                                        ? [s.card, s.cardAlt]
                                        : [s.premium, s.premiumDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: sel
                                        ? s.premium.withAlpha(180)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: sel
                                      ? [
                                          BoxShadow(
                                            color: s.premium.withAlpha(60),
                                            blurRadius: 10,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: sel
                                    ? Icon(
                                        Icons.check,
                                        color: s.premiumLight,
                                        size: 20,
                                      )
                                    : null,
                              ),
                              SizedBox(height: 6),
                              Text(
                                s.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: sel ? AppColors.ink : AppColors.gray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // ===== 设置卡 =====
            FrostedCard(
              radius: 14,
              padding: EdgeInsets.zero,
              child: _menuRow(
                Icons.settings_outlined,
                '设置',
                AppColors.inkSecondary,
                () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(
    IconData icon,
    String title,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, color: AppColors.ink)),
      trailing: Icon(Icons.chevron_right, color: AppColors.gray, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minTileHeight: 52,
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();
  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.only(left: 68), child: Divider());
}

// ===== 个人信息弹窗（简化） =====
class _PersonalInfoSheet extends StatefulWidget {
  final String nickname;
  final String? avatarPath;
  final VoidCallback onSaved;
  const _PersonalInfoSheet({
    required this.nickname,
    required this.avatarPath,
    required this.onSaved,
  });
  @override
  State<_PersonalInfoSheet> createState() => _PersonalInfoSheetState();
}

class _PersonalInfoSheetState extends State<_PersonalInfoSheet> {
  late TextEditingController _nickCtrl, _phoneCtrl, _signCtrl;
  String _gender = '';

  static const _genders = ['男', '女', '保密'];
  static const _fallbackRegions = {
    '北京': {
      '北京市': [
        '东城区',
        '西城区',
        '朝阳区',
        '海淀区',
        '丰台区',
        '石景山区',
        '通州区',
        '大兴区',
        '顺义区',
        '昌平区',
      ],
    },
    '上海': {
      '上海市': [
        '黄浦区',
        '徐汇区',
        '长宁区',
        '静安区',
        '浦东新区',
        '虹口区',
        '杨浦区',
        '闵行区',
        '宝山区',
        '嘉定区',
        '松江区',
      ],
    },
    '天津': {
      '天津市': ['和平区', '河东区', '河西区', '南开区', '河北区', '红桥区', '滨海新区'],
    },
    '重庆': {
      '重庆市': ['渝中区', '江北区', '沙坪坝区', '九龙坡区', '南岸区', '渝北区', '巴南区'],
    },
    '广东': {
      '广州市': ['天河区', '越秀区', '海珠区', '荔湾区', '白云区', '番禺区', '黄埔区'],
      '深圳市': ['南山区', '福田区', '宝安区', '龙岗区', '罗湖区', '龙华区', '光明区'],
      '东莞市': ['莞城区', '南城区', '东城区', '万江区'],
      '佛山市': ['禅城区', '南海区', '顺德区', '三水区'],
      '珠海市': ['香洲区', '斗门区', '金湾区'],
    },
    '浙江': {
      '杭州市': ['西湖区', '上城区', '拱墅区', '滨江区', '余杭区', '萧山区', '临平区'],
      '宁波市': ['海曙区', '鄞州区', '江北区', '北仑区', '镇海区'],
      '温州市': ['鹿城区', '龙湾区', '瓯海区'],
      '嘉兴市': ['南湖区', '秀洲区'],
    },
    '江苏': {
      '南京市': ['玄武区', '鼓楼区', '秦淮区', '建邺区', '江宁区', '栖霞区', '浦口区'],
      '苏州市': ['姑苏区', '虎丘区', '工业园区', '吴中区', '相城区', '吴江区'],
      '无锡市': ['梁溪区', '锡山区', '惠山区', '滨湖区', '新吴区'],
      '常州市': ['天宁区', '钟楼区', '新北区', '武进区'],
    },
    '四川': {
      '成都市': ['锦江区', '武侯区', '高新区', '青羊区', '金牛区', '成华区', '天府新区'],
      '绵阳市': ['涪城区', '游仙区'],
    },
    '湖北': {
      '武汉市': ['武昌区', '洪山区', '江汉区', '江岸区', '硚口区', '汉阳区', '青山区'],
      '宜昌市': ['西陵区', '伍家岗区'],
      '襄阳市': ['襄城区', '樊城区'],
    },
    '湖南': {
      '长沙市': ['岳麓区', '芙蓉区', '天心区', '开福区', '雨花区', '望城区'],
      '株洲市': ['天元区', '芦淞区'],
      '湘潭市': ['雨湖区', '岳塘区'],
    },
    '福建': {
      '厦门市': ['思明区', '湖里区', '集美区', '海沧区', '同安区'],
      '福州市': ['鼓楼区', '台江区', '仓山区', '晋安区', '马尾区'],
      '泉州市': ['鲤城区', '丰泽区', '洛江区'],
    },
    '山东': {
      '济南市': ['历下区', '市中区', '槐荫区', '天桥区', '历城区', '长清区'],
      '青岛市': ['市南区', '市北区', '崂山区', '李沧区', '城阳区', '黄岛区'],
      '烟台市': ['芝罘区', '福山区', '莱山区'],
    },
    '安徽': {
      '合肥市': ['蜀山区', '包河区', '庐阳区', '瑶海区', '滨湖新区'],
      '芜湖市': ['镜湖区', '弋江区', '鸠江区'],
    },
    '河南': {
      '郑州市': ['金水区', '二七区', '中原区', '管城区', '惠济区', '郑东新区'],
      '洛阳市': ['洛龙区', '西工区', '涧西区'],
    },
    '河北': {
      '石家庄市': ['长安区', '桥西区', '新华区', '裕华区'],
      '唐山市': ['路北区', '路南区'],
      '保定市': ['竞秀区', '莲池区'],
    },
    '辽宁': {
      '沈阳市': ['和平区', '沈河区', '皇姑区', '大东区', '铁西区', '浑南新区'],
      '大连市': ['中山区', '西岗区', '沙河口区', '甘井子区'],
    },
    '陕西': {
      '西安市': ['雁塔区', '碑林区', '未央区', '长安区', '莲湖区', '新城区'],
      '咸阳市': ['秦都区', '渭城区'],
    },
    '江西': {
      '南昌市': ['东湖区', '西湖区', '青山湖区', '红谷滩区'],
      '赣州市': ['章贡区'],
    },
    '广西': {
      '南宁市': ['青秀区', '兴宁区', '西乡塘区', '良庆区'],
      '桂林市': ['秀峰区', '叠彩区', '象山区', '七星区'],
    },
    '云南': {
      '昆明市': ['五华区', '盘龙区', '官渡区', '西山区', '呈贡区'],
      '大理市': ['大理市辖区'],
    },
    '贵州': {
      '贵阳市': ['南明区', '云岩区', '观山湖区', '花溪区'],
      '遵义市': ['红花岗区', '汇川区'],
    },
    '山西': {
      '太原市': ['小店区', '迎泽区', '杏花岭区', '万柏林区'],
      '大同市': ['平城区'],
    },
    '吉林': {
      '长春市': ['南关区', '朝阳区', '宽城区', '二道区', '绿园区'],
      '吉林市': ['船营区', '昌邑区'],
    },
    '黑龙江': {
      '哈尔滨市': ['道里区', '南岗区', '道外区', '松北区', '香坊区'],
      '齐齐哈尔市': ['龙沙区', '建华区'],
    },
    '甘肃': {
      '兰州市': ['城关区', '七里河区', '西固区', '安宁区'],
    },
    '海南': {
      '海口市': ['龙华区', '美兰区', '秀英区', '琼山区'],
      '三亚市': ['吉阳区', '天涯区', '海棠区'],
    },
    '内蒙古': {
      '呼和浩特市': ['新城区', '回民区', '玉泉区', '赛罕区'],
      '包头市': ['昆都仑区', '青山区'],
    },
    '新疆': {
      '乌鲁木齐市': ['天山区', '沙依巴克区', '新市区', '水磨沟区'],
    },
    '西藏': {
      '拉萨市': ['城关区'],
    },
    '宁夏': {
      '银川市': ['兴庆区', '西夏区', '金凤区'],
    },
    '青海': {
      '西宁市': ['城东区', '城中区', '城西区', '城北区'],
    },
    '台湾': {
      '台北市': ['信义区', '大安区', '中山区', '松山区'],
      '高雄市': ['苓雅区', '前镇区'],
    },
    '香港': {
      '香港': ['中西区', '湾仔区', '东区', '南区'],
    },
    '澳门': {
      '澳门': ['澳门半岛', '氹仔', '路环'],
    },
  };
  Map<String, Map<String, List<String>>>? _loadedRegions;
  Map<String, Map<String, List<String>>> get _regions =>
      _loadedRegions ?? _fallbackRegions;
  String _province = '', _city = '', _district = '';

  @override
  void initState() {
    super.initState();
    _nickCtrl = TextEditingController(text: widget.nickname);
    _phoneCtrl = TextEditingController();
    _signCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, Map<String, List<String>>>? loadedRegions;
    try {
      loadedRegions = (await ChinaRegions.load()).data;
    } catch (_) {
      // Keep the small embedded fallback available if an older install has
      // not refreshed its asset bundle yet.
    }
    if (!mounted) return;
    setState(() {
      _loadedRegions = loadedRegions;
      _gender = prefs.getString('profile_gender') ?? '';
      _province = prefs.getString('profile_province') ?? '';
      _city = prefs.getString('profile_city') ?? '';
      _district = prefs.getString('profile_district') ?? '';
      _phoneCtrl.text = prefs.getString('profile_phone') ?? '';
      _signCtrl.text = prefs.getString('profile_signature') ?? '';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_nickname', _nickCtrl.text.trim());
    await prefs.setString('profile_gender', _gender);
    await prefs.setString('profile_province', _province);
    await prefs.setString('profile_city', _city);
    await prefs.setString('profile_district', _district);
    await prefs.setString('profile_phone', _phoneCtrl.text.trim());
    await prefs.setString('profile_signature', _signCtrl.text.trim());
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  String get _regionText {
    if (_province.isEmpty) return '';
    if (_city.isEmpty) return _province;
    if (_district.isEmpty) return '$_province·$_city';
    return '$_province·$_city·$_district';
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _phoneCtrl.dispose();
    _signCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  '个人信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey('profile-save-hit-target'),
                  onPressed: _save,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(
                    '完成',
                    style: TextStyle(color: AppColors.sage, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              children: [
                _tf('昵称', _nickCtrl),
                _pick('性别', _gender.isNotEmpty ? _gender : '选择', () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => Padding(
                      padding: EdgeInsets.all(24),
                      child: FrostedCard(
                        padding: EdgeInsets.all(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _genders
                              .map(
                                (g) => ListTile(
                                  title: Text(g),
                                  trailing: _gender == g
                                      ? Icon(Icons.check, color: AppColors.sage)
                                      : null,
                                  onTap: () {
                                    setState(() => _gender = g);
                                    Navigator.pop(context);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  );
                }),
                _pick(
                  '地区',
                  _regionText.isNotEmpty ? _regionText : '选择',
                  () => _pickRegion(),
                ),
                _tf(
                  '手机号',
                  _phoneCtrl,
                  hint: '手机号码',
                  keyboardType: TextInputType.phone,
                ),
                _tf('个性签名', _signCtrl, hint: '介绍你自己', maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pickRegion() {
    String? p = _province, c = _city, d = _district;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                color: AppColors.bgSheet,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.gray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          '选择地区',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _province = p ?? '';
                              _city = c ?? '';
                              _district = d ?? '';
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            '确定',
                            style: TextStyle(color: AppColors.sage),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView(
                            children: _regions.keys
                                .map(
                                  (pn) => ListTile(
                                    title: Text(
                                      pn,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: p == pn
                                            ? AppColors.ink
                                            : AppColors.gray,
                                        fontWeight: p == pn
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    selected: p == pn,
                                    onTap: () {
                                      setInner(() {
                                        p = pn;
                                        final cities = _regions[pn]!;
                                        c = cities.keys.first;
                                        d = cities[c]!.first;
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        Container(width: 0.5, color: AppColors.divider),
                        Expanded(
                          child: p != null && p!.isNotEmpty
                              ? ListView(
                                  children: _regions[p]!.keys
                                      .map(
                                        (cn) => ListTile(
                                          title: Text(
                                            cn,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: c == cn
                                                  ? AppColors.ink
                                                  : AppColors.gray,
                                              fontWeight: c == cn
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          selected: c == cn,
                                          onTap: () {
                                            setInner(() {
                                              c = cn;
                                              d = _regions[p]![c!]!.first;
                                            });
                                          },
                                        ),
                                      )
                                      .toList(),
                                )
                              : SizedBox(),
                        ),
                        Container(width: 0.5, color: AppColors.divider),
                        Expanded(
                          child:
                              p != null &&
                                  p!.isNotEmpty &&
                                  c != null &&
                                  c!.isNotEmpty
                              ? ListView(
                                  children: _regions[p]![c]!
                                      .map(
                                        (dn) => ListTile(
                                          title: Text(
                                            dn,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: d == dn
                                                  ? AppColors.ink
                                                  : AppColors.gray,
                                              fontWeight: d == dn
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          selected: d == dn,
                                          onTap: () => setInner(() => d = dn),
                                        ),
                                      )
                                      .toList(),
                                )
                              : SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _tf(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: AppColors.ink),
              ),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: keyboardType,
                maxLines: maxLines,
                style: TextStyle(fontSize: 14, color: AppColors.ink),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: AppColors.gray),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pick(String label, String value, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, color: AppColors.ink),
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: value.contains('选择') ? AppColors.gray : AppColors.ink,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: AppColors.gray),
            ],
          ),
        ),
      ),
    );
  }
}
