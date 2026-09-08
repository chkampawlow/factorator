import 'package:flutter/material.dart';
import 'package:my_app/services/assistant_service.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';

class AssistantScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const AssistantScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final AssistantService _assistantService = AssistantService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_AssistantMessage> _messages = <_AssistantMessage>[];

  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _messages.add(
        _AssistantMessage(
          role: _AssistantRole.assistant,
          content: _welcomeText(),
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _welcomeText() {
    final locale = Localizations.localeOf(context).languageCode;
    switch (locale) {
      case 'ar':
        return 'مرحبًا! أنا مساعد El Fatoura. اسألني عن الفواتير أو الحرفاء أو المنتجات أو أي خطوة داخل التطبيق.';
      case 'fr':
        return 'Bonjour ! Je suis l’assistant El Fatoura. Pose-moi une question sur les factures, les clients, les produits ou une étape dans l’application.';
      default:
        return 'Hello! I am the El Fatoura assistant. Ask me about invoices, clients, products, or any step inside the app.';
    }
  }

  String _titleText() {
    final locale = Localizations.localeOf(context).languageCode;
    switch (locale) {
      case 'ar':
        return 'المساعد';
      case 'fr':
        return 'Assistant';
      default:
        return 'Assistant';
    }
  }

  String _subtitleText() {
    final locale = Localizations.localeOf(context).languageCode;
    switch (locale) {
      case 'ar':
        return 'اطرح سؤالك وسأجيب مباشرة من خلال مساعد التطبيق.';
      case 'fr':
        return 'Posez votre question et obtenez une réponse directe depuis l’assistant de l’application.';
      default:
        return 'Ask your question and get a direct answer from the in-app assistant.';
    }
  }

  String _composerHint() {
    final locale = Localizations.localeOf(context).languageCode;
    switch (locale) {
      case 'ar':
        return 'اكتب رسالتك هنا...';
      case 'fr':
        return 'Écrivez votre message ici...';
      default:
        return 'Write your message here...';
    }
  }

  String _emptyMessageError() {
    final locale = Localizations.localeOf(context).languageCode;
    switch (locale) {
      case 'ar':
        return 'اكتب رسالة أولاً.';
      case 'fr':
        return 'Écrivez un message d’abord.';
      default:
        return 'Write a message first.';
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      AppAlerts.info(context, _emptyMessageError());
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _messages.add(
        _AssistantMessage(
          role: _AssistantRole.user,
          content: text,
          createdAt: DateTime.now(),
        ),
      );
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final reply = await _assistantService.sendMessage(text);
      if (!mounted) return;

      setState(() {
        _messages.add(
          _AssistantMessage(
            role: _AssistantRole.assistant,
            content: reply,
            createdAt: DateTime.now(),
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppTopBar(
        title: _titleText(),
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer
                          .withValues(alpha: isDark ? 0.42 : 0.72),
                      cs.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: cs.outlineVariant
                        .withValues(alpha: isDark ? 0.26 : 0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: cs.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titleText(),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _subtitleText(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_sending && index == _messages.length) {
                    return _TypingBubble(
                      isDark: isDark,
                    );
                  }

                  final message = _messages[index];
                  final isUser = message.role == _AssistantRole.user;
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: const BoxConstraints(maxWidth: 720),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: isUser
                            ? cs.primary
                            : cs.surfaceContainerHighest.withValues(
                                alpha: isDark ? 0.56 : 0.92,
                              ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(22),
                          topRight: const Radius.circular(22),
                          bottomLeft: Radius.circular(isUser ? 22 : 8),
                          bottomRight: Radius.circular(isUser ? 8 : 22),
                        ),
                        border: Border.all(
                          color: isUser
                              ? cs.primary
                              : cs.outlineVariant.withValues(
                                  alpha: isDark ? 0.22 : 0.14,
                                ),
                        ),
                      ),
                      child: SelectableText(
                        message.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                          color: isUser ? cs.onPrimary : cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: _composerHint(),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _sending ? null : _sendMessage,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  cs.onPrimary,
                                ),
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AssistantRole { user, assistant }

class _AssistantMessage {
  final _AssistantRole role;
  final String content;
  final DateTime createdAt;

  const _AssistantMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });
}

class _TypingBubble extends StatelessWidget {
  final bool isDark;

  const _TypingBubble({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.56 : 0.92,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(22),
          ),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.14),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(),
            SizedBox(width: 6),
            _Dot(),
            SizedBox(width: 6),
            _Dot(),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot();

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.28, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: child,
        );
      },
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
