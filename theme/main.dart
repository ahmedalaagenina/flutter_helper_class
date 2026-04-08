import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typo_color_them/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      lazy: false,
      create: (_) => ThemeBloc(prefs)..add(const ThemeInitialize()),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ThemeBloc,
      ThemeState,
      ({ThemeData lightTheme, ThemeData darkTheme, ThemeMode themeMode})
    >(
      selector: (state) => (
        lightTheme:
            state.lightThemeData ??
            state.createThemeData(brightness: Brightness.light),
        darkTheme:
            state.darkThemeData ??
            state.createThemeData(brightness: Brightness.dark),
        themeMode: state.themeMode,
      ),
      builder: (context, themeConfig) {
        return MaterialApp(
          title: 'Flutter Theme Demo',
          theme: themeConfig.lightTheme,
          darkTheme: themeConfig.darkTheme,
          themeMode: themeConfig.themeMode,
          home: const HomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final colors = appTheme.colors;
    final typography = appTheme.typography;
    return Scaffold(
      appBar: AppBar(
        title: Text('Theme System', style: typography.headlineMedium),
        actions: [
          // Theme toggle button
          BlocBuilder<ThemeBloc, ThemeState>(
            buildWhen: (previous, current) =>
                previous.themeMode != current.themeMode,
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : state.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_auto,
                ),
                onPressed: () {
                  final currentMode = state.themeMode;
                  final newMode = currentMode == ThemeMode.light
                      ? ThemeMode.dark
                      : currentMode == ThemeMode.dark
                      ? ThemeMode.system
                      : ThemeMode.light;

                  context.read<ThemeBloc>().add(ThemeModeChanged(newMode));
                },
              );
            },
          ),

          // Font selection menu
          BlocBuilder<ThemeBloc, ThemeState>(
            buildWhen: (previous, current) =>
                previous.typographyFont != current.typographyFont,
            builder: (context, state) {
              return PopupMenuButton<AppTypographyFont>(
                onSelected: (font) {
                  context.read<ThemeBloc>().add(TypographyFontChanged(font));
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: AppTypographyFont.appDefault,
                    child: Text('Default'),
                  ),
                  const PopupMenuItem(
                    value: AppTypographyFont.roboto,
                    child: Text('Roboto'),
                  ),
                  const PopupMenuItem(
                    value: AppTypographyFont.cairo,
                    child: Text('Cairo'),
                  ),
                  const PopupMenuItem(
                    value: AppTypographyFont.arabicTypography,
                    child: Text('Arabic Typography'),
                  ),
                  const PopupMenuItem(
                    value: AppTypographyFont.englishTypography,
                    child: Text('English Typography'),
                  ),
                ],
              );
            },
          ),

          // Font size scale factor menu
          BlocBuilder<ThemeBloc, ThemeState>(
            buildWhen: (previous, current) =>
                previous.fontSizeScaleFactor != current.fontSizeScaleFactor,
            builder: (context, state) {
              return PopupMenuButton<double>(
                tooltip: 'Font size',
                icon: const Icon(Icons.format_size),
                onSelected: (scaleFactor) {
                  context.read<ThemeBloc>().add(
                    FontSizeScaleFactorChanged(scaleFactor),
                  );
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 0.8, child: Text('Small (0.8x)')),
                  const PopupMenuItem(
                    value: 0.9,
                    child: Text('Medium Small (0.9x)'),
                  ),
                  const PopupMenuItem(value: 1.0, child: Text('Normal (1.0x)')),
                  const PopupMenuItem(
                    value: 1.1,
                    child: Text('Medium Large (1.1x)'),
                  ),
                  const PopupMenuItem(value: 1.2, child: Text('Large (1.2x)')),
                  const PopupMenuItem(
                    value: 1.3,
                    child: Text('Extra Large (1.3x)'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Typography demonstration
            _buildSection(
              title: 'Typography',
              typography: typography,
              colors: colors,
              children: [
                Text('Display Large', style: typography.displayLarge),
                const SizedBox(height: 8),
                Text('Display Medium', style: typography.displayMedium),
                const SizedBox(height: 8),
                Text('Display Small', style: typography.displaySmall),
                const SizedBox(height: 8),
                Text('Headline Large', style: typography.headlineLarge),
                const SizedBox(height: 8),
                Text('Headline Medium', style: typography.headlineMedium),
                const SizedBox(height: 8),
                Text('Headline Small', style: typography.headlineSmall),
                const SizedBox(height: 16),
                Text(
                  'Body Large: Lorem ipsum dolor sit amet',
                  style: typography.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Body Medium: Lorem ipsum dolor sit amet',
                  style: typography.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Body Small: Lorem ipsum dolor sit amet',
                  style: typography.bodySmall,
                ),
              ],
            ),

            // Color demonstration
            _buildSection(
              title: 'Colors',
              typography: typography,
              colors: colors,
              children: [
                _ColorRow(name: 'Primary', color: colors.primary),
                _ColorRow(name: 'Primary Dark', color: colors.primaryDark),
                _ColorRow(name: 'Primary Light', color: colors.primaryLight),
                _ColorRow(name: 'Secondary', color: colors.secondary),
                _ColorRow(name: 'Background', color: colors.background),
                _ColorRow(name: 'Surface', color: colors.surface),
                _ColorRow(name: 'Error', color: colors.error),
                _ColorRow(name: 'Success', color: colors.success),
                _ColorRow(name: 'Warning', color: colors.warning),
                _ColorRow(name: 'Info', color: colors.info),
              ],
            ),

            // Theme settings section
            _buildSection(
              title: 'Theme Settings',
              typography: typography,
              colors: colors,
              children: [
                BlocBuilder<ThemeBloc, ThemeState>(
                  buildWhen: (previous, current) =>
                      previous.themeMode != current.themeMode ||
                      previous.fontSizeScaleFactor !=
                          current.fontSizeScaleFactor,
                  builder: (context, state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Theme Mode Selector
                        Text('Theme Mode:', style: typography.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _ThemeModeButton(
                              mode: ThemeMode.light,
                              label: 'Light',
                              isSelected: state.themeMode == ThemeMode.light,
                              icon: Icons.light_mode,
                              onPressed: () => context.read<ThemeBloc>().add(
                                const ThemeModeChanged(ThemeMode.light),
                              ),
                            ),
                            _ThemeModeButton(
                              mode: ThemeMode.dark,
                              label: 'Dark',
                              isSelected: state.themeMode == ThemeMode.dark,
                              icon: Icons.dark_mode,
                              onPressed: () => context.read<ThemeBloc>().add(
                                const ThemeModeChanged(ThemeMode.dark),
                              ),
                            ),
                            _ThemeModeButton(
                              mode: ThemeMode.system,
                              label: 'System',
                              isSelected: state.themeMode == ThemeMode.system,
                              icon: Icons.brightness_auto,
                              onPressed: () => context.read<ThemeBloc>().add(
                                const ThemeModeChanged(ThemeMode.system),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Font Size Slider
                        Text('Font Size Scale:', style: typography.titleMedium),
                        Row(
                          children: [
                            const Text('0.8'),
                            Expanded(
                              child: Slider(
                                value: state.fontSizeScaleFactor,
                                min: 0.8,
                                max: 1.4,
                                divisions: 12,
                                label:
                                    '${state.fontSizeScaleFactor.toStringAsFixed(1)}x',
                                onChanged: (value) {
                                  context.read<ThemeBloc>().add(
                                    FontSizeScaleFactorChanged(value),
                                  );
                                },
                              ),
                            ),
                            const Text('1.4'),
                          ],
                        ),
                        // Add this inside the Theme Settings section in HomePage
                        const SizedBox(height: 16),
                        // Reset Button
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset Theme Settings'),
                            onPressed: () {
                              context.read<ThemeBloc>().add(const ThemeReset());
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

            // Update the About section with the custom date format and username
            // About section
            _buildSection(
              title: 'About',
              typography: typography,
              colors: colors,
              children: [
                Text(
                  'This is a demonstration of a theming system built using the BLoC pattern for state management.',
                  style: typography.bodyMedium,
                ),
                const SizedBox(height: 8),
                BlocBuilder<ThemeBloc, ThemeState>(
                  buildWhen: (_, __) =>
                      true, // Update every build for accurate time
                  builder: (context, _) {
                    final now = DateTime.now().toUtc();
                    final formattedDate =
                        '${now.year}-'
                        '${now.month.toString().padLeft(2, '0')}-'
                        '${now.day.toString().padLeft(2, '0')} '
                        '${now.hour.toString().padLeft(2, '0')}:'
                        '${now.minute.toString().padLeft(2, '0')}:'
                        '${now.second.toString().padLeft(2, '0')}';

                    return Text(
                      'Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): $formattedDate',
                      style: typography.bodyMedium,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Current User\'s: AhmedAlaaGenina',
                  style: typography.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required BaseTypography typography,
    required BaseColors colors,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: typography.headlineSmall.copyWith(color: colors.primary),
            ),
            const Divider(height: 32),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String name;
  final Color color;

  const _ColorRow({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final typography = appTheme.typography;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: appTheme.colors.onBackground.withOpacity(0.2),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: typography.titleLarge),
                Text(
                  '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                  style: typography.bodySmall.copyWith(
                    color: appTheme.colors.onBackground.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  final ThemeMode mode;
  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onPressed;

  const _ThemeModeButton({
    required this.mode,
    required this.label,
    required this.isSelected,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appTheme.colors;
    final typography = context.typography;

    return ElevatedButton.icon(
      icon: Icon(icon, color: isSelected ? colors.onPrimary : null),
      label: Text(
        label,
        style: typography.labelLarge.copyWith(
          color: isSelected ? colors.onPrimary : null,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? colors.primary : colors.surface,
        foregroundColor: isSelected ? colors.onPrimary : colors.onSurface,
      ),
      onPressed: onPressed,
    );
  }
}
