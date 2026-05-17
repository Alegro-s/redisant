import 'package:flutter/material.dart';

class LegalNoticeScreen extends StatefulWidget {
  const LegalNoticeScreen({super.key, this.initialTab = 'privacy'});

  final String initialTab;

  @override
  State<LegalNoticeScreen> createState() => _LegalNoticeScreenState();
}

class _LegalNoticeScreenState extends State<LegalNoticeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialTab == 'terms' ? 1 : 0;
    _tabs = TabController(length: 2, vsync: this, initialIndex: idx);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Документы · Lynx Launcher'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Конфиденциальность'),
            Tab(text: 'Условия'),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final maxW = wide ? 760.0 : c.maxWidth;
          return TabBarView(
            controller: _tabs,
            children: [
              _LegalScrollPane(
                maxWidth: maxW,
                sections: _kPrivacySections,
                footer: _kLawyerFooter,
                accent: cs.primary,
              ),
              _LegalScrollPane(
                maxWidth: maxW,
                sections: _kTermsSections,
                footer: _kLawyerFooter,
                accent: cs.primary,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegalScrollPane extends StatelessWidget {
  const _LegalScrollPane({
    required this.maxWidth,
    required this.sections,
    required this.footer,
    required this.accent,
  });

  final double maxWidth;
  final List<_LegalSection> sections;
  final String footer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = EdgeInsets.fromLTRB(
      20,
      20,
      20,
      24 + MediaQuery.paddingOf(context).bottom,
    );

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: pad,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const SizedBox(height: 22),
                    _SectionBlock(section: sections[i], accent: accent, theme: theme),
                  ],
                  const SizedBox(height: 28),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        footer,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.45,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.accent,
    required this.theme,
  });

  final _LegalSection section;
  final Color accent;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 22,
              margin: const EdgeInsets.only(top: 2, right: 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in section.paragraphs) ...[
                Text(
                  p,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

const String _kLawyerFooter =
    'Этот документ носит информационный характер и не заменяет юридическую консультацию. '
    'Перед публичным или коммерческим релизом согласуйте тексты с юристом с учётом применимого права '
    '(в т.ч. 152-ФЗ, GDPR и требований магазинов приложений).';

const List<_LegalSection> _kPrivacySections = [
  _LegalSection('1. Общие положения', [
    'Настоящая политика описывает, как приложение Lynx Launcher и связанные сервисы экосистемы Lynx '
        '(далее — «Сервис») обрабатывают информацию при использовании вами аккаунта, облачных функций и встроенных модулей.',
    'Оператором и контактными данными для запросов по персональным данным считается лицо или организация, '
        'указанные в вашем договоре или на публичной странице проекта. При самостоятельном развёртывании (self-host) '
        'оператором является владелец сервера.',
  ]),
  _LegalSection('2. Какие данные мы можем обрабатывать', [
    'Учётные данные: адрес электронной почты, никнейм, при необходимости — номер телефона, имя (ФИО), '
        'хеш пароля на стороне сервера, настройки профиля и выбранные вами модули интерфейса.',
    'Технические данные: тип устройства, версия приложения, диагностические журналы при сбоях (если вы включили отправку), '
        'сетевые обращения к API (IP-адрес, время запроса) — в объёме, необходимом для безопасности и работы Сервиса.',
    'Контент, который вы создаёте в Сервисе: сообщения, файлы проектов, метаданные сборок — в соответствии с функциями модулей, '
        'которыми вы пользуетесь.',
  ]),
  _LegalSection('3. Цели обработки', [
    'Создание и ведение аккаунта, аутентификация, восстановление доступа, поддержка пользователей.',
    'Предоставление функций Lynx Hub, проектов, мессенджера, новостной ленты, каталога Lynx Cloud и иных включённых модулей.',
    'Обеспечение безопасности (предотвращение злоупотреблений, расследование инцидентов), соблюдение законных требований.',
  ]),
  _LegalSection('4. Файлы cookie и локальное хранилище', [
    'Клиентское приложение может сохранять на устройстве токены входа, настройки темы и модулей, базовый URL API — '
        'чтобы не вводить их при каждом запуске.',
    'Веб-версии сайтов экосистемы могут использовать cookie и аналогичные технологии; их состав указывается в политике '
        'соответствующего сайта.',
  ]),
  _LegalSection('5. Передача и хранение', [
    'Данные обрабатываются на инфраструктуре, выбранной оператором Сервиса (в т.ч. облачные хостинг-провайдеры). '
        'При передаче в третьи страны должны применяться подходящие гарантии (в соответствии с применимым правом).',
    'Сроки хранения определяются необходимостью предоставления Сервиса и требованиями закона; часть данных может быть удалена '
        'после удаления аккаунта, если иное не требуется для учёта или споров.',
  ]),
  _LegalSection('6. Безопасность', [
    'Мы применяем организационные и технические меры (в т.ч. шифрование канала HTTPS, ограничение доступа к серверам). '
        'Ни один канал не гарантирует абсолютную безопасность; рекомендуем использовать устойчивый пароль и не передавать '
        'учётные данные третьим лицам.',
  ]),
  _LegalSection('7. Ваши права', [
    'В зависимости от юрисдикции вы можете иметь право на доступ, исправление, удаление персональных данных, ограничение '
        'или возражение против обработки, переносимость данных, отзыв согласия (если обработка на нём основана).',
    'Для реализации прав обратитесь к оператору через контакт, указанный в приложении или на сайте проекта. '
        'Вы также вправе подать жалобу в надзорный орган.',
  ]),
  _LegalSection('8. Изменения политики', [
    'Мы можем обновлять политику; актуальная версия публикуется в приложении. Продолжение использования после существенных '
        'изменений может означать согласие с новой редакцией — в порядке, предусмотренном применимым правом.',
  ]),
];

const List<_LegalSection> _kTermsSections = [
  _LegalSection('1. Принятие условий', [
    'Устанавливая, регистрируясь или используя Lynx Launcher и связанные сервисы Lynx, вы подтверждаете, что прочитали и '
        'соглашаетесь с настоящими условиями. Если вы не согласны, не используйте Сервис.',
    'Для отдельных функций (облако, маркетплейс, интеграции) могут действовать дополнительные условия или политики.',
  ]),
  _LegalSection('2. Описание сервиса', [
    'Сервис предоставляет клиентское приложение и, при наличии аккаунта, доступ к облачным API: управление проектами, '
        'коммуникации, новости, каталоги сборок и иные модули, включённые оператором.',
    'Функции могут изменяться, временно приостанавливаться для обслуживания или по причинам вне контроля оператора.',
  ]),
  _LegalSection('3. Аккаунт и доступ', [
    'Вы обязуетесь указывать достоверные данные при регистрации и хранить пароль и токены в тайне. Вы несёте ответственность '
        'за действия, совершённые под вашим аккаунтом.',
    'Оператор вправе ограничить или заблокировать аккаунт при нарушении условий, угрозе безопасности или по требованию закона.',
  ]),
  _LegalSection('4. Допустимое использование', [
    'Запрещено использовать Сервис для противоправной деятельности, нарушения прав третьих лиц, распространения вредоносного кода, '
        'несанкционированного сканирования, перегрузки инфраструктуры (DoS), обхода технических ограничений.',
    'Контент и проекты не должны нарушать законодательство и права других пользователей.',
  ]),
  _LegalSection('5. Интеллектуальная собственность и контент', [
    'Права на программное обеспечение Lynx Launcher и брендинг принадлежат правообладателям. Права на контент, который вы '
        'загружаете в Сервис, сохраняются за вами; для работы Сервиса вы предоставляете оператору необходимую неисключительную '
        'лицензию на обработку и отображение такого контента в рамках функций продукта.',
  ]),
  _LegalSection('6. Отказ от гарантий и ограничение ответственности', [
    'Сервис предоставляется «как есть» в пределах, допускаемых законом. Оператор не гарантирует бесперебойную работу и '
        'пригодность для конкретных целей.',
    'В максимальной степени, разрешённой применимым правом, оператор не несёт ответственности за косвенные убытки, упущенную '
        'выгоду, потерю данных из-за действий третьих лиц или сбоев связи на стороне пользователя.',
  ]),
  _LegalSection('7. Расторжение', [
    'Вы можете прекратить использование и запросить удаление аккаунта в порядке, предусмотренном интерфейсом или поддержкой. '
        'Оператор может прекратить доступ при прекращении обслуживания с уведомлением, если это возможно.',
  ]),
  _LegalSection('8. Применимое право и споры', [
    'Применимое право и подсудность определяются в зависимости от оператора Сервиса и договора с пользователем; при отсутствии '
        'специального соглашения применяются нормы страны регистрации оператора или условия магазина приложений.',
  ]),
  _LegalSection('9. Контакты', [
    'По вопросам условий использования обращайтесь через официальные каналы поддержки проекта, указанные на сайте или в приложении.',
  ]),
];
