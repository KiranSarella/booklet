import 'dart:async';

import 'package:flutter/material.dart';
import 'package:booklet/application/editor_controller.dart';

class BookletSearchView extends StatefulWidget {
  const BookletSearchView({
    super.key,
    required this.controller,
    required this.onResult,
    required this.onClose,
  });
  final EditorController controller;
  final void Function(
    String pageId,
    String query,
    int index,
    bool caseSensitive,
  )
  onResult;
  final VoidCallback onClose;

  @override
  State<BookletSearchView> createState() => BookletSearchViewState();
}

class BookletSearchViewState extends State<BookletSearchView> {
  void focusSearch() {
    _focus.requestFocus();
    _query.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _query.text.length,
    );
  }

  String? _documentPath;

  @override
  void initState() {
    super.initState();
    _documentPath = widget.controller.documentPath;
  }

  @override
  void didUpdateWidget(covariant BookletSearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_documentPath != widget.controller.documentPath) {
      _documentPath = widget.controller.documentPath;
      _query.clear();
      _timer?.cancel();
      ++_request;
      _results = [];
      _busy = false;
      _error = null;
    }
  }

  bool _caseSensitive = false;
  bool _showReplace = false;
  bool _replacing = false;
  final _replacement = TextEditingController();

  Future<void> _replace({bool all = false}) async {
    setState(() => _replacing = true);
    try {
      final count = await widget.controller.replaceBookletMatches(
        _query.text,
        _replacement.text,
        caseSensitive: _caseSensitive,
        all: all,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Replaced $count ${count == 1 ? 'match' : 'matches'}'),
        ),
      );
      _schedule(_query.text);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Replacement failed. Some pages may already be updated.',
        );
      }
    } finally {
      if (mounted) setState(() => _replacing = false);
    }
  }

  final _query = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _request = 0;
  bool _busy = false;
  String? _error;
  List<BookletSearchPage> _results = [];

  void _schedule(String value) {
    _timer?.cancel();
    final request = ++_request;
    setState(() {
      _busy = value.isNotEmpty;
      _error = null;
      _results = [];
    });
    if (value.isEmpty) return;
    _timer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await widget.controller.searchBooklet(
          value,
          caseSensitive: _caseSensitive,
        );
        if (!mounted || request != _request) return;
        setState(() {
          _results = results;
          _busy = false;
        });
      } catch (_) {
        if (!mounted || request != _request) return;
        setState(() {
          _error = 'Could not search all pages. Try again.';
          _busy = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    _replacement.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _snippet(BookletSearchHit hit) {
    final start = (hit.start - 45).clamp(0, hit.text.length);
    final end = (hit.end + 65).clamp(0, hit.text.length);
    String clean(String value) => value.replaceAll('\n', ' ');
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text:
                '${start > 0 ? '…' : ''}${clean(hit.text.substring(start, hit.start))}',
          ),
          TextSpan(
            text: clean(hit.text.substring(hit.start, hit.end)),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          TextSpan(
            text:
                '${clean(hit.text.substring(hit.end, end))}${end < hit.text.length ? '…' : ''}',
          ),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _results.fold<int>(
      0,
      (total, page) => total + page.hits.length,
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              enabled: !_replacing,
              controller: _query,
              focusNode: _focus,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search booklet…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _schedule,
              onSubmitted: _schedule,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: _showReplace ? 'Hide replace' : 'Show replace',
                  isSelected: _showReplace,
                  icon: Icon(
                    _showReplace ? Icons.expand_more : Icons.chevron_right,
                  ),
                  onPressed: _replacing
                      ? null
                      : () => setState(() => _showReplace = !_showReplace),
                ),
                IconButton(
                  tooltip: 'Match case',
                  isSelected: _caseSensitive,
                  icon: const Icon(Icons.text_fields),
                  onPressed: _replacing
                      ? null
                      : () {
                          setState(() => _caseSensitive = !_caseSensitive);
                          _schedule(_query.text);
                        },
                ),
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear_all),
                  onPressed: _replacing
                      ? null
                      : () {
                          _query.clear();
                          _replacement.clear();
                          _schedule('');
                          _focus.requestFocus();
                        },
                ),
                IconButton(
                  tooltip: 'Close booklet search',
                  icon: const Icon(Icons.close),
                  onPressed: _replacing ? null : widget.onClose,
                ),
              ],
            ),
          ),
          if (_showReplace) ...[
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _replacement,
                enabled:
                    !_replacing &&
                    !widget.controller.documentSettingsController.isReadOnly,
                decoration: const InputDecoration(
                  hintText: 'Replace with',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _busy ||
                          _replacing ||
                          count == 0 ||
                          widget
                              .controller
                              .documentSettingsController
                              .isReadOnly
                      ? null
                      : () => _replace(),
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed:
                      _busy ||
                          _replacing ||
                          count == 0 ||
                          widget
                              .controller
                              .documentSettingsController
                              .isReadOnly
                      ? null
                      : () => _replace(all: true),
                  child: const Text('Replace all'),
                ),
              ],
            ),
          ],
          if (_replacing) const LinearProgressIndicator(),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (!_busy && _error == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _query.text.isEmpty
                    ? 'Search titles and content across all pages.'
                    : _results.isEmpty
                    ? 'No results found.'
                    : '$count content ${count == 1 ? 'match' : 'matches'} across ${_results.length} ${_results.length == 1 ? 'page' : 'pages'}',
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final page in _results) ...[
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.description_outlined, size: 18),
                    title: Text(page.title),
                    subtitle: page.breadcrumb.isEmpty
                        ? null
                        : Text(page.breadcrumb),
                    trailing: Text('${page.hits.length}'),
                    onTap: () => widget.onResult(
                      page.pageId,
                      _query.text,
                      page.hits.isEmpty ? -1 : 0,
                      _caseSensitive,
                    ),
                  ),
                  for (var i = 0; i < page.hits.length; i++)
                    ListTile(
                      dense: true,
                      title: _snippet(page.hits[i]),
                      onTap: () => widget.onResult(
                        page.pageId,
                        _query.text,
                        i,
                        _caseSensitive,
                      ),
                    ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
