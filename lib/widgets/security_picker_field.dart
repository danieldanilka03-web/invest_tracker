import 'package:flutter/material.dart';
import '../data/securities.dart';
import '../data/security_info.dart';
import '../services/favorites_service.dart';
import 'ticker_avatar.dart';

/// Поле выбора бумаги с автокомплитом по встроенному справочнику.
/// Позволяет либо выбрать готовую бумагу, либо ввести свою (для того,
/// чего нет в справочнике).
class SecurityPickerField extends StatelessWidget {
  final void Function(SecurityInfo) onSelected;
  final String hintText;

  const SecurityPickerField({
    super.key,
    required this.onSelected,
    this.hintText = 'Тикер или название бумаги',
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<SecurityInfo>(
      displayStringForOption: (s) => '${s.ticker} — ${s.name}',
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          final favTickers = FavoritesService.all;
          if (favTickers.isEmpty) return SecuritiesDatabase.search('');
          final favs = favTickers
              .map((t) => SecuritiesDatabase.byTicker(t))
              .whereType<SecurityInfo>()
              .toList();
          return favs;
        }
        return SecuritiesDatabase.search(textEditingValue.text);
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: hintText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 400),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    dense: true,
                    leading: TickerAvatar(ticker: s.ticker, size: 32),
                    title: Text(s.ticker, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${s.name} • ${s.sector.isEmpty ? "Без сектора" : s.sector}'),
                    trailing: StatefulBuilder(
                      builder: (context, setInnerState) => IconButton(
                        icon: Icon(
                          FavoritesService.isFavorite(s.ticker) ? Icons.star : Icons.star_border,
                          color: FavoritesService.isFavorite(s.ticker) ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () async {
                          await FavoritesService.toggle(s.ticker);
                          setInnerState(() {});
                        },
                      ),
                    ),
                    onTap: () => onSelected(s),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
