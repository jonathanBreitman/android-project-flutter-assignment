import 'dart:io' as DART_IO;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'dart:ui';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path_provider/path_provider.dart';






void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp();
  runApp(ChangeNotifierProvider(create: (_) => AppUser(),
    child: App()));
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startup Name Generator',
      theme: ThemeData(
        primaryColor: Colors.red,
        dividerColor: Colors.green,
      ),
      home: RandomWords(),
    );
  }
}




class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  var _saved = <WordPair>{};
  final _biggerFont = TextStyle(fontSize: 18.0);

  FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoggedIn = false;
  bool isLoginButtonDisabled = false;
  bool isSignupButtonDisabled = false;
  bool isConfirmButtonDisabled = false;
  final SnappingSheetController snapCntrl = SnappingSheetController();
  bool isConfirmError = false;



  @override
  Widget build(BuildContext context) {
    _auth = FirebaseAuth.instance;
    if(isLoggedIn) {
      getSavedFromCloud();
    }
    return Scaffold (
      appBar: AppBar(
        title: Text('Startup Name Generator'),
        actions: [
          IconButton(icon: Icon(Icons.favorite), onPressed: _pushSaved),
          IconButton(icon: isLoggedIn? Icon(Icons.exit_to_app): Icon(Icons.login), tooltip: "go to login screen", onPressed: isLoggedIn? Logout: _goToLogin)
        ],
      ),
      body: _buildMainPage(),
    );
  }

  Widget _buildMainPage(){
    if (Provider.of<AppUser>(context, listen: false).isAuthenticated){
      final String email = getCurEmailFromCloud();
      final snapPos0 = SnappingPosition.factor(
        positionFactor: 0.0,
        snappingCurve: Curves.easeOutExpo,
        snappingDuration: Duration(seconds: 1),
        grabbingContentOffset: GrabbingContentOffset.top,
      );
      final snapPos1 = SnappingPosition.factor(
        snappingCurve: Curves.elasticOut,
        snappingDuration: Duration(milliseconds: 1750),
        positionFactor: 0.2,
      );
      final snapPos2 = SnappingPosition.factor(
        grabbingContentOffset: GrabbingContentOffset.bottom,
        snappingCurve: Curves.easeInExpo,
        snappingDuration: Duration(seconds: 1),
        positionFactor: 0.9,
      );

      final mySnapSheet = SnappingSheet(
        controller: snapCntrl,
        lockOverflowDrag: true,
        snappingPositions: [
          snapPos0, snapPos1, snapPos2
        ],
        grabbing: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(blurRadius: 25, color: Colors.black.withOpacity(0.2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('Welcome back, $email'),
                GestureDetector(
                  onTap: () {
                      if (snapCntrl.currentSnappingPosition == snapPos0){
                        snapCntrl.snapToPosition(snapPos2);
                      }
                      else{
                        snapCntrl.snapToPosition(snapPos0);
                      }
                  },
                  child: Icon(Icons.keyboard_arrow_up),
                ),
              ],
            )
        ),
        grabbingHeight: 75,
        sheetAbove: null,
        sheetBelow: SnappingSheetContent(
          //TO DO
          //add snap content here
            sizeBehavior: SheetSizeFill(),
            draggable:  true,
            child: Container(
                color: Colors.white,
                child: ListTile(
                  leading: Image(image: NetworkImage(Provider.of<AppUser>(context, listen: false).profilePickUrl)),
                  title: Text(email),
                  subtitle: ElevatedButton(
                    onPressed: () async{
                      DART_IO.File _image;
                      ImagePicker imPick = ImagePicker();
                      final pickedFile = await imPick.getImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        _image = DART_IO.File(pickedFile.path);
                        String uid = getCurIDFromCloud();
                        await firebase_storage.FirebaseStorage.instance.ref().child(uid).putFile(_image);
                        Provider.of<AppUser>(context, listen: false).getPicUrl();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No image selected')));
                      }
                    },
                    child: Text('Change avatar'),
                  ),

                )
            )

        ),
        onSheetMoved: (pos){
          Provider.of<AppUser>(context, listen: false).blurSugestions();
        },
        onSnapCompleted: (sheetPos, snapPos){
          Provider.of<AppUser>(context, listen: false).unblurSugestions();
        },
      );

      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildSuggestions(),
          Positioned.fill(child: BackdropFilter(
            filter: (Provider.of<AppUser>(context)._blurSuggestions)? ImageFilter.blur(
              sigmaX: 8.0,
              sigmaY: 8.0,
            ) : ImageFilter.blur(
              sigmaX: 0.0,
              sigmaY: 0.0,
            ),
            child: mySnapSheet,
          ))

        ],
      );
    }
    else{
      return _buildSuggestions();
    }
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          Provider.of<AppUser>(context);
          final tiles = _saved.map(
                (WordPair pair) {
              return ListTile(
                title: Text(
                  pair.asPascalCase,
                  style: _biggerFont,
                ),
                trailing: Icon(Icons.delete),
                onTap: (){
                  _saved.remove(pair);
                  if(isLoggedIn) {
                    updateSavedOnCloud();
                  }
                },
              );
            },
          );
          final divided = ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList();

          return Scaffold(
            appBar: AppBar(
              title: Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  void _goToLogin(){
    isLoginButtonDisabled = false;
    isSignupButtonDisabled = false;
    isConfirmButtonDisabled = false;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context){
          final emailController = TextEditingController();
          final passwordController = TextEditingController();
          final confirmPassController = TextEditingController();
          final confirmKey = GlobalKey<FormState>();

          return Scaffold(
            appBar: AppBar(
              title: Text('Login'),
              centerTitle: true,
            ),
            body: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter Email',
                      ),
                      controller: emailController,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: TextFormField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Enter Password',
                      ),
                      controller: passwordController,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isLoginButtonDisabled? null: () async{
                      isLoginButtonDisabled = true;
                      _auth = FirebaseAuth.instance;
                      setState(() {

                      });

                      Provider.of<AppUser>(context, listen: false).setStatus(Status.Authenticating);

                      try{

                        await _auth.signInWithEmailAndPassword(email: emailController.text, password: passwordController.text);

                      }
                      catch(e){
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('There was an error logging into the app')));
                        Provider.of<AppUser>(context).setStatus(Status.Unauthenticated);
                        isLoggedIn = false;
                        isLoginButtonDisabled = false;
                        return;
                      }
                      //if got here login was successful
                      isLoggedIn = true;
                      //update the saved list both on the cloud and in the ui

                      await updateSavedUpponLogin();

                      isLoginButtonDisabled = false;

                      //update authentication status
                      Provider.of<AppUser>(context, listen:  false).setStatus(Status.Authenticated);

                      //navigate back to the last screen
                      Navigator.of(context).pop();
                      setState(() {

                      });
                    },
                    child: Text(isLoginButtonDisabled? '...': 'Login'),
                    style: ElevatedButton.styleFrom(minimumSize: Size(200,30)),
                  ),
                  ElevatedButton(
                    onPressed: isSignupButtonDisabled? null: () async{

                      isSignupButtonDisabled = true;
                      isConfirmError = false;
                      _auth = FirebaseAuth.instance;
                      setState(() {

                      });

                      Provider.of<AppUser>(context, listen: false).setStatus(Status.Authenticating);

                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Form(
                          key: confirmKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text('Please confirm your password below:'),
                              TextFormField(
                                autovalidate: isConfirmError,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Password',
                                ),
                                controller: confirmPassController,
                                validator: (value){
                                  isConfirmButtonDisabled = false;
                                  if (value != passwordController.text){
                                    isConfirmError = true;
                                    return "Passwords must match";
                                  }
                                  isConfirmError = false;
                                  return null;
                                },
                              ),
                              ElevatedButton(
                                onPressed: isConfirmButtonDisabled? null: () async {
                                  isConfirmButtonDisabled = true;
                                  if (confirmKey.currentState?.validate() ==
                                      false) {
                                    Provider.of<AppUser>(context).setStatus(
                                        Status.Unauthenticated);
                                    isLoggedIn = false;
                                    isSignupButtonDisabled = false;
                                    isConfirmButtonDisabled = false;
                                    setState(() {

                                    });
                                  }
                                  else {
                                    isLoggedIn = true;
                                    await Provider.of<AppUser>(context, listen: false).signUp(emailController.text, passwordController.text);
                                    await updateSavedUpponLogin();

                                    isConfirmButtonDisabled = false;
                                    isSignupButtonDisabled = false;
                                    //update authentication status
                                    Provider.of<AppUser>(
                                        context, listen: false)
                                        .setStatus(Status.Authenticated);

                                    //navigate back to the last screen
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    setState(() {

                                    });
                                  }
                                },
                                child: Text(isConfirmButtonDisabled? '...': 'Confirm'),
                                style: ElevatedButton.styleFrom(minimumSize: Size(150,30)),
                              )
                            ],
                          ),
                        ),
                      );

                    },
                    child: Text(isSignupButtonDisabled? '...': 'New user? Click to sign up'),
                    style: ElevatedButton.styleFrom(minimumSize: Size(200,30)),
                  ),
                ]
            ),
          );
        }
      ),
    );
  }



  Future<void> Logout() async{
    updateSavedOnCloud();
    this._auth.signOut();
    this.isLoggedIn = false;
    setState(() {

    });
  }


  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        // The itemBuilder callback is called once per suggested
        // word pairing, and places each suggestion into a ListTile
        // row. For even rows, the function adds a ListTile row for
        // the word pairing. For odd rows, the function adds a
        // Divider widget to visually separate the entries. Note that
        // the divider may be difficult to see on smaller devices.
        itemBuilder: (BuildContext _context, int i) {
          // Add a one-pixel-high divider widget before each row
          // in the ListView.
          if (i.isOdd) {
            return Divider();
          }

          // The syntax "i ~/ 2" divides i by 2 and returns an
          // integer result.
          // For example: 1, 2, 3, 4, 5 becomes 0, 1, 1, 2, 2.
          // This calculates the actual number of word pairings
          // in the ListView,minus the divider widgets.
          final int index = i ~/ 2;
          // If you've reached the end of the available word
          // pairings...
          if (index >= _suggestions.length) {
            // ...then generate 10 more and add them to the
            // suggestions list.
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        }
    );
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);

    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Colors.red : null,
      ),
      onTap: () {     
        setState(() {
          if (alreadySaved) {
            _saved.remove(pair);
          } else {
            _saved.add(pair);
          }
          if(isLoggedIn) {
            updateSavedOnCloud();
          }
        });
      },
    );
  }

  Future<void> updateSavedUpponLogin() async{
    try {
      DocumentSnapshot userFromDB = await FirebaseFirestore.instance.collection(
          "Users").doc(_auth.currentUser!.uid).get();
      for (String str in (userFromDB.data()!['savedPairs'])) {
        List twoWords = str.split(" ");
        WordPair wp = WordPair(twoWords[0], twoWords[1]);
        _saved.add(wp);
      }
      updateSavedOnCloud();
    }
    catch(e){
      print(e);
      print("DB ERROR\n");
    }
  }

  Future<void> updateSavedOnCloud() async{
    List<String> wordPairs = List.filled(_saved.length, "");
    int i = 0;
    for (WordPair wp in _saved){
      wordPairs[i] = wp.first + " " + wp.second;
      i+=1;
    }
    await FirebaseFirestore.instance.collection(
        "Users").doc(_auth.currentUser!.uid).update({'savedPairs': wordPairs});
    await getSavedFromCloud();
    setState(() {
      Provider.of<AppUser>(context, listen: false).notifyListeners();
    });
  }

  Future<void> getSavedFromCloud() async{
    var dbUser = await FirebaseFirestore.instance.collection(
        "Users").doc(_auth.currentUser!.uid).get();
    _saved = <WordPair>{};
    for (String str in (dbUser.data()!['savedPairs'])) {
      List twoWords = str.split(" ");
      WordPair wp = WordPair(twoWords[0], twoWords[1]);
      _saved.add(wp);
    }
  }

  String getCurEmailFromCloud() {
    _auth = FirebaseAuth.instance;
    return _auth.currentUser!.email!;
  }

  String getCurIDFromCloud() {
    _auth = FirebaseAuth.instance;
    return _auth.currentUser!.uid;
  }

  Future<String> getProfilePicFromCloud() async{
    var dbUser = await FirebaseFirestore.instance.collection(
        "Users").doc(_auth.currentUser!.uid).get();
    return dbUser.data()!['profilePictureUrl'];
  }
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
                body: Center(
                    child: Text(snapshot.error.toString(),
                        textDirection: TextDirection.ltr)));
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return MyApp();
          }
          return Center(child: CircularProgressIndicator());
        },
    );
  }
}


enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class AppUser with ChangeNotifier {
  FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  Status _status = Status.Uninitialized;
  bool _blurSuggestions = false;
  String profilePickUrl = 'http://www.clker.com/cliparts/u/2/A/u/A/t/blank-profile-head-md.png';

  AppUser() {
    Firebase.initializeApp();
    _user = _auth.currentUser;
    getPicUrl();
    _onAuthStateChanged(_user);
  }

  Status get status => _status;

  void setStatus(stat){
    this._status=stat;
    notifyListeners();
  }

  User? get user => _user;

  bool get isAuthenticated => status == Status.Authenticated;

  Future<void> getPicUrl() async{
    profilePickUrl = await firebase_storage.FirebaseStorage.instance.ref().child(_user!.uid).getDownloadURL();
    notifyListeners();
  }

  void blurSugestions(){
    _blurSuggestions = true;
    notifyListeners();
  }

  void unblurSugestions(){
    _blurSuggestions = false;
    notifyListeners();
  }

  Future<UserCredential?> signUp(String email, String password) async {
    _auth = FirebaseAuth.instance;
    _status = Status.Authenticating;
    notifyListeners();
    await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password);
    _user = _auth.currentUser;
    Map<String, dynamic>data = {'email': email, 'savedPairs': List.filled(0, "")};
    await FirebaseFirestore.instance.collection(
        "Users").add(data);
    DART_IO.Directory appDir = await getApplicationDocumentsDirectory();
    String filePath = '${appDir.absolute}/no_profile_pic.jpg';
    await firebase_storage.FirebaseStorage.instance.ref().child(_user!.uid).putFile(DART_IO.File(filePath));
  }

  Future<bool> login(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = _auth.currentUser;
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      _user = null;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    await _auth.signOut();
    _status = Status.Unauthenticated;
    _user = null;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }
}


