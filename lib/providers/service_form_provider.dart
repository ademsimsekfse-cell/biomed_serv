@@
-class ServiceFormProvider with ChangeNotifier {
-  final DatabaseService _dbService;
-  late Box<ServiceForm> _formBox;
-  StreamSubscription<BoxEvent>? _formSubscription;
-
-  List<ServiceForm> _forms = [];
-  List<ServiceForm> get forms => _forms;
-
-  ServiceFormProvider(this._dbService) {
-    _formBox = _dbService.serviceFormsBox;
-    _formSubscription = _formBox.watch().listen((_) => _loadForms());
-    _loadForms();
-  }
+class ServiceFormProvider with ChangeNotifier {
+  final DatabaseService _dbService;
+  final SyncIntegration? _syncIntegration;
+  late Box<ServiceForm> _formBox;
+  StreamSubscription<BoxEvent>? _formSubscription;
+
+  List<ServiceForm> _forms = [];
+  List<ServiceForm> get forms => _forms;
+
+  ServiceFormProvider(this._dbService, [this._syncIntegration]) {
+    _formBox = _dbService.serviceFormsBox;
+    _formSubscription = _formBox.watch().listen((_) => _loadForms());
+    _loadForms();
+  }
*** End Patch