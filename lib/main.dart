import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Autumn Product Manager',
      home: ProductPage(),
    ),
  );
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = FirebaseFirestore.instance.collection('products');
  late final _productStream = _products.snapshots();
  final _searchController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    _minController.clear();
    _maxController.clear();

    setState(() {});
  }

  Future<void> _createOrUpdate([
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) =>
          ProductEditor(products: _products, document: document),
    );
  }

  Future<void> _deleteProduct(String id) async {
    try {
      //delete the product by its ID
      await _products.doc(id).delete();

      //check if the widget still exists
      if (!mounted) return;

      //show success only after deletion completes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully.')),
      );
    } on FirebaseException catch (error) {
      //check if the widget still exists
      if (!mounted) return;

      //show error message if deletion fails
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: ${error.code}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autumn Product Manager')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Products could not load. Check connection and permissions.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final documents = snapshot.data!.docs;
          if (documents.isEmpty) {
            return const Center(
              child: Text('No products yet. Add one to begin.'),
            );
          }
          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              final data = document.data();
              final name = data['name'];
              final price = data['price'];
              if (name is! String ||
                  name.trim().isEmpty ||
                  price is! num ||
                  !price.isFinite ||
                  price < 0) {
                return ListTile(
                  title: Text(
                    'Invalid product ${document.id}: check name/price types.',
                  ),
                );
              }
              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(
                    '${price.toStringAsFixed(2)}\nID: ${document.id}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit product',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _createOrUpdate(document),
                      ),
                      IconButton(
                        tooltip: 'Delete product',
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteProduct(document.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create product',
        onPressed: () => _createOrUpdate(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.products, this.document});

  final CollectionReference<Map<String, dynamic>> products;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.document?.data()['name'] as String? ?? '',
  );
  late final _price = TextEditingController(
    text: widget.document?.data()['price']?.toString() ?? '',
  );
  var _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final data = <String, Object>{
      'name': _name.text.trim(),
      'price': double.parse(_price.text.trim()),
    };
    try {
      final document = widget.document;
      if (document == null) {
        await widget.products.add(data);
      } else {
        await widget.products.doc(document.id).update(data);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      debugPrint('Product save failed (${error.code}): ${error.message}');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Save failed (${error.code}). '
            'Check your connection and permissions.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.document == null ? 'Create product' : 'Edit product',
                ),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a product name'
                      : null,
                ),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || !amount.isFinite || amount < 0
                        ? 'Enter a finite price of zero or more'
                        : null;
                  },
                ),
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saving)
                  const Text(
                    'Awaiting server acknowledgement. If offline, reconnect. '
                    'This editor stays open until the write succeeds or fails.',
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
