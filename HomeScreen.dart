import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:date_format/date_format.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stathero/Models/Login/UserData.dart';
import 'package:stathero/Models/Login/app_user.dart';
import 'package:stathero/Models/category/category_data.dart';
import 'package:stathero/Screens/Profile/ProfileScreen.dart';
import 'package:stathero/Screens/contest/ContestScreen.dart';
import 'package:stathero/Screens/contest/rivals/rivals_screen.dart';
import 'package:stathero/Screens/payment/select_amount.dart';
import 'package:stathero/Screens/picplayer/no_teams_capitan_no_salary/new_page_pick_no_teams.dart';
import 'package:stathero/Screens/selectmatch/alertPage.dart';
import 'package:stathero/Screens/selectmatch/notificationPage.dart';
import 'package:stathero/Screens/verification/verification.dart';
import 'package:stathero/Screens/webview/WebViewScreen.dart';
import 'package:stathero/Utils/AssetStrings.dart';
import 'package:stathero/Utils/Constants.dart';
import 'package:stathero/Utils/GeocomplyLocationHelper.dart';
import 'package:stathero/Utils/ReusableWidgets.dart';
import 'package:stathero/Utils/StatHeroColors.dart';
import 'package:stathero/Utils/StatHeroFunctions.dart';
import 'package:stathero/Utils/UniversalFunctions.dart';
import 'package:stathero/Utils/Variables.dart';
import 'package:stathero/Utils/labelStrings.dart';
import 'package:stathero/Utils/memory_management.dart';
import 'package:stathero/blocs/HomeBloc.dart';
import 'package:share/share.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'bonus_dialog.dart';
import 'oops_dialog.dart';

class HomeScreen extends StatefulWidget {

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {

  var location = new Location();

  static HomeBloc homeBloc;

  final FirebaseMessaging _fcm = FirebaseMessaging();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const platform = const MethodChannel('luxuryandclassic.com.stathero/geocomplylocation');
  AppUser user;
  //List<CategoryData> categoryList = [];
  var timeout = const Duration(seconds: 3);
  var ms = const Duration(milliseconds: 1);

  //to show  loader
  StreamController<bool> _streamControllerShowLoader =
  new StreamController<bool>();

  num coins = 0;
  String documentID = "";

  final flutterWebviewPlugin = new FlutterWebviewPlugin();
  var kAndroidUserAgent = 'Mozilla/5.0 (Linux; Android 4.4.4; One Build/KTU84L.H4) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/33.0.0.0 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/28.0.0.20.16;]';

  StreamSubscription _onDestroy;

  StreamSubscription<String> _onUrlChanged;
  bool _isLoading = false;
  final _scaffoldKey = new GlobalKey<ScaffoldState>();

  var lat=0.0;
  var lng=0.0;
  var altitude=0.0;
  var speed=0.0;
  var _coins;
  var _bonusCoins;
  final formatCurrency = NumberFormat.simpleCurrency();

  Uint8List userAvatarImageData;

  @override
  void initState() {
    super.initState();
    getCategories();
    _fcm.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        showFCMNotificaitonAlert(message);
      },
      onBackgroundMessage: fcmBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {showFCMNotificaitonAlert(message);},
      onResume: (Map<String, dynamic> message) async {showFCMNotificaitonAlert(message);},
    );
    var userInfo = jsonDecode(MemoryManagement.getUserInfo());
    user = AppUser.fromJson(userInfo);
    getUserDetails();
    webViewListeners();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      // todo uncomment for release
      //if(!Variables.redirectToMyContests) {
      // GeocomplyLocationHelper.newCheckGeocomplyLocationByTimer(_showSuccessLocationVerifiedDialog, context, "Enter Application", null);
      // Variables.redirectToMyContests = false;
      //}
    });
  }

  void showFCMNotificaitonAlert(Map<String, dynamic> message) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (BuildContext context, _, __) =>
            NotificationPage(title: message['notification']['title'], message: message['notification']['body']),
      ),
    );
  }

  static Future<dynamic> fcmBackgroundMessageHandler(Map<String, dynamic> message) {
    if (message.containsKey('data')) {
      // Handle data message
      final dynamic data = message['data'];
      print("Notification come 1");
      print(data);
    }

    if (message.containsKey('notification')) {
      // Handle notification message
      final dynamic notification = message['notification'];
      print("Notification come 2");
      print(notification);
    }

    return null;
    // Or do other work.
  }

  void firebaseCloudMessagingListeners() {
    if (Platform.isIOS) iOSPermission();

    _fcm.getToken().then((token){
      updateToken(token);
    });
  }

  void iOSPermission() {
    _fcm.requestNotificationPermissions(
        IosNotificationSettings(sound: true, badge: true, alert: true)
    );
    _fcm.onIosSettingsRegistered
        .listen((IosNotificationSettings settings)
    {
      print("Settings registered: $settings");
    });
  }

  Future<FirebaseUser> _getUser() {
    return _auth.currentUser().then((FirebaseUser user) {
        return user;
      },
    );
  }

  webViewListeners() {
    _onDestroy = flutterWebviewPlugin.onDestroy.listen((_) {
      if (mounted) {
        _scaffoldKey.currentState.showSnackBar(
            const SnackBar(content: const Text('Webview Destroyed')));
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _streamControllerShowLoader.add(false);
    flutterWebviewPlugin.close();

  }

  Future<bool> _onBackPressed() async {
    flutterWebviewPlugin.close();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return /*Container(
      color: Colors.green,
    );*/ WillPopScope(
      onWillPop: _onBackPressed,
      child: SafeArea(
        top: false,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: StatHeroColors.blackBackground,
          body: Stack(
            children: <Widget>[
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 16, left: 16, bottom: 85),
                  child: Column(
                    children: <Widget>[
                      _buildTopView(),
                      _buildCenterView(),
                      _buildBtnGroup(),
                      new SizedBox(
                        height: 14,
                      ),
                      Padding(
                          padding: EdgeInsets.only(left: 20, right: 20),
                          child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                      text: StatHeroStrings.shared.gamblingInfoHomeScreen,
                        style: TextStyle(fontSize: 10, color: Colors.white),
                        children: <TextSpan>[
                          TextSpan(text: " "),
                          TextSpan(text:  StatHeroStrings.shared.gamblingUrl,
                              style: TextStyle(color: Colors.blue),
                          recognizer: new TapGestureRecognizer()
                        ..onTap = () { launch(StatHeroStrings.shared.gamblingUrl);
                        }),
                        ],
                      ),
                ),
                            )
                    ],
                  ),
                ),
              ),
              _loader()
            ],
          ),
        ),
      ),
    );
  }

  Widget _loader() {
    return new StreamBuilder<bool>(
        stream: _streamControllerShowLoader.stream,
        initialData: false,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          bool status = snapshot.data;
          return status
              ? Center(child: CupertinoActivityIndicator())
              : new Container();
        });
  }

   getUserDetails()  async {
    CollectionReference collectionReference = Firestore.instance.collection("Users");
    Query query = collectionReference.where('email', isEqualTo: user.data.email).limit(1);
    UserData userData;
    //add  details
   var userDataValue = await query.getDocuments();//.then((value) {
      var userInfo = userDataValue.documents.first;
      documentID = userInfo.documentID;
      user.data = UserData.fromJson(userInfo.data);
      var uId = userInfo.documentID;
      user.data.id = uId;
      Stream<QuerySnapshot> firestoreReference = Firestore.instance.collection('Users').where('email', isEqualTo: user.data.email).limit(1).snapshots();
      //firestoreReference.listen((data) => data.documents.forEach((doc) => this._coins = doc.data['coins']));
      firestoreReference.listen((data) {
        data.documents.forEach((doc) {
          if (!mounted) return;
          setState(() {
            this._coins = doc.data['coins'];
            this._bonusCoins = doc.data['bonusCoins'];
          });
        });
      });
     /* try {
        FirebaseStorage().ref().child(user.data.id)
            .getData(maxsize).then((Uint8List value) {
          if (value != null && value.isNotEmpty) {
            setState(() {
              userAvatarImageData = value;
            });
          }
        });
      }
       catch (e){

      }*/

      firebaseCloudMessagingListeners();
      //print(userData.avatarUrl);
      check();
  /*  }).catchError((error) {
      print(error.toString());
    });*/
    return userData;

      }



  void check() async {

    CollectionReference collectionReference = Firestore.instance.collection("Users");
    Query query = collectionReference.where('email', isEqualTo: user.data.email).limit(1);

    await query.getDocuments().then((value) async {
     var isIdVerifiedField = false;
      value.documents.forEach((DocumentSnapshot docSnap) {

      var verifiedOnField = docSnap.data['verifiedOn'];
      if (verifiedOnField != null) {
        isIdVerifiedField = true;
      } else {
        _redirect();
      }
      });

      if (isIdVerifiedField == true) {
        return;
      } else {
        _redirect();
      }
    }).catchError((error) {
      print(error);
    });

  }

  void _redirect() {
//    Navigator.push(
//      context,
//      CupertinoPageRoute(
//        builder: (BuildContext context) {
//          return Verification();
//        },
//      ),
//    );
  }

  _buildTopView() {
    return Column(
      children: <Widget>[
        SizedBox(
          height: STATUS_BAR_HEIGHT,
        ),
        Stack(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      InkWell(
                        onTap: () async {
                          int apiHit =
                          await Navigator.of(context, rootNavigator: true).push(
                            new CupertinoPageRoute(
                              fullscreenDialog: true,
                              builder: (BuildContext context) {
                                return new ProfileScreen(
                                    user
                                );
                              },
                            ),
                          );
                          if (apiHit != null) {
                            switch (apiHit) {
                              case 0:
                                getUserDetails();
                                break;
                              default:
                                break;
                            }
                          }
                        },
                        child: Container(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                getScreenSize(context: context).height * 0.07),
                            child: _getImage(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 16,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${user.data.username}',
                              style: TextStyle(color: Colors.white, fontSize: 15),
                            ),
                            SizedBox(
                              height: 4,
                            ),

                            Text(
                              _coins != null ? '${(formatCurrency.format(_coins/100))}' : '0.00',
                              style: TextStyle(color: Colors.green, fontSize: 15),
                            ),
                            SizedBox(height: 1,),
                            Text(
                              _bonusCoins != null ? '${(formatCurrency.format(_bonusCoins.toDouble()/100))}' : '0.00',
                              style: TextStyle(color: Colors.blue, fontSize: 15),
                            ),


                          ],
                        ),
                      )
                    ],
                  ),
                ),
                _depositBtn(),
                new Container(width: 10),
                //_notificationBtn()
              ],
            ),
            Positioned(
              top: 1,
              left: 55,
              child: Container(
                alignment: Alignment.topCenter,
                width: getScreenSize(context: context).width * 0.08,
                height: getScreenSize(context: context).height * 0.08,
                child: Image.asset("assets/icons/profile_expert_logo.png"),
              ),
            ),

          ],
        ),
        SizedBox(height: 11),
        Divider(
          color: Color(0xffFFFFFF).withOpacity(0.54),
        )
      ],
    );
  }

  _buildCenterView() {
    return Column(
      children: <Widget>[
        getSpacer(height: 6),
        _rivalsView(),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _blackContainer(_NBAClicked(getNBADocumentReferenceFromCategories()), AssetStrings.NBA_LOGO),
            _blackContainer(_MLBClicked(getMLBDocumentRefecrenceFromCategories()), AssetStrings.MLB_LOGO),
          ],
        ),
        getSpacer(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _blackContainer(_NHLClicked(getNFLDocumentRefecrenceFromCategories()), AssetStrings.NHL_LOGO),
            _blackContainer(_NFLClicked(getNFLDocumentRefecrenceFromCategories()), AssetStrings.NFL_LOGO),
          ],
        ),
        getSpacer(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _blackContainer(_PGAClicked(getPGADocumentReferenceFromCategories()), AssetStrings.PGA_LOGO),
            _blackContainer(_NascarClicked(getNASDocumentReferenceFromCategories()), AssetStrings.NASCAR_LOGO),
          ],
        ),
      ],
    );
  }

  _buildBtnGroup() {
    return Column(
      children: <Widget>[
        getSpacer(height: 20),
        //TODO: 'Add check if Tour Seen or Not'; (Implement Tour Screens);
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildBtn(txt: "Rules & Scoring", url: "https://stathero.com/scoring/"),
            SizedBox(
              width: 10,
            ),
            _buildBtn(
                txt: "Refund Policy",
                url: "https://stathero.com/refund/"),
          ],
        ),
        getSpacer(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildBtn(
                txt: "Terms / Conditions",
                url: "https://stathero.com/terms/"),
            SizedBox(
              width: 10,
            ),
            _buildBtn(
                txt: "Privacy Policy",
                url: "https://stathero.com/privacy/"),
          ],
        ),
        getSpacer(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildBtn(
                txt: "Responsible Gaming",
                url: "https://www.ncpgambling.org/"),
            SizedBox(
              width: 10,
            ),
            _buildRedBtn(asset: "assets/icons/BonusText.png"),
          ],
        ),
      ],
    );
  }

  Widget _rivalsView(){
    return InkWell(onTap: (){
      moveToRivals();
    },
      child: Container(
        child: Stack(
          children: <Widget>[
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Image.asset(AssetStrings.RIVALS_BACK_LOGO,
                  width: (getScreenSize(context: context).width) - 33,
                  height: 116.0,
                  fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Image.asset(AssetStrings.RIVALS_LOGO,
                    width: 135,
                    height: 80.0,
                    fit: BoxFit.fill),
              ),
            ),
          ],
        ),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 0.1)),
      ),
    );
  }


  int maxsize = 10e6.round();
  Widget _getImage() {

    /*  return FutureBuilder ( // I also think getting Data, instead of a DownloadUrl is more practical here. It keeps the data more secure, instead of generating a DownloadUrl  which is accesible for everyone who knows it.
        future: getUserDetails(),
        builder: (BuildContext context, AsyncSnapshot snapshot2) {
          // When this builder is called, the Future is already resolved into snapshot.data
          // So snapshot.data contains the not-yet-correctly formatted Image.
          //return Image.memory(data, fit: BoxFit.Cover);
          return  snapshot2 != null ?*/
    return  FutureBuilder<Uint8List> ( // I also think getting Data, instead of a DownloadUrl is more practical here. It keeps the data more secure, instead of generating a DownloadUrl  which is accesible for everyone who knows it.
        future: FirebaseStorage().ref().child(user.data.id)
            .getData(maxsize),
        builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
          // When this builder is called, the Future is already resolved into snapshot.data
          // So snapshot.data contains the not-yet-correctly formatted Image.

          //return Image.memory(data, fit: BoxFit.Cover);

          return ( !snapshot.hasData || snapshot.hasError)
              ? Image.asset(
            AssetStrings.userAvatar,
            fit: BoxFit.fill,
            height: getScreenSize(context: context).height * 0.10,
            width: getScreenSize(context: context).height * 0.10,
          )
              : Image.memory(
            snapshot.data,
            fit: BoxFit.fill,
            height: getScreenSize(context: context).height * 0.10,
            width: getScreenSize(context: context).height * 0.10,
          );



        });
    /* : Container()
          ; })*/;}
//  Widget get _getImage {
//
//         return (userAvatarImageData == null || userAvatarImageData.isEmpty)
//          ? Image.asset(
//            AssetStrings.userAvatar,
//            fit: BoxFit.fill,
//            height: getScreenSize(context: context).height * 0.10,
//            width: getScreenSize(context: context).height * 0.10,
//          )
//              : Image.memory(
//            userAvatarImageData,
//            fit: BoxFit.fill,
//            height: getScreenSize(context: context).height * 0.10,
//            width: getScreenSize(context: context).height * 0.10,
//          );
//
// }

  Widget _depositBtn() {
    return SizedBox(
      height: 35,
      width: 100,
      child: new FlatButton(
          child: new Text(
            "DEPOSIT",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          onPressed: () {

            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => SelectAmountScreen(getScreenSize(context: context).width)),
            );
          },
          textColor: StatHeroColors.kPrimaryGreen,
          shape: new RoundedRectangleBorder(
              borderRadius: new BorderRadius.circular(4.0),
              side: BorderSide(color:StatHeroColors.kPrimaryGreen, width: 1))),
    );
  }

  Widget _blackContainer(VoidCallback onTap, String logourl) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        overflow: Overflow.visible,
        children: <Widget>[
          Container(
              height: 110.0,
              width: (getScreenSize(context: context).width / 2) - 22,
              decoration: BoxDecoration(
                  color: Color(0xff171B22),
                  border: Border.all(color: StatHeroColors.whiteColor, width: 0.1),
                  borderRadius: BorderRadius.all(Radius.circular(8))),
              child: Center(
                child: Image.asset(
                  logourl,
                  width: 115.0,
                  height: 75.0,
                  fit: BoxFit.scaleDown,
                ),
              )),
//          Positioned(right: -10, top: -10,
//              child: Container(width: 20, height: 20, decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(10)), color: Colors.yellow),
//                alignment: Alignment.center,
//                child: Text("1", style: TextStyle(color: Colors.black),))),
        ],
      ),
    );
  }

  Widget _buildBtn({@required String txt, @required String url}) {

    return SizedBox(
      height: 55,
      width: (getScreenSize(context: context).width / 2) - 30,
      child: FlatButton(
        child: Text(
          txt,
          style: TextStyle(fontSize: 12),
        ),
        color: txt == 'Invite a friend' ? StatHeroColors.nav_home_color : null,
        onPressed: () {
          url == 'https://apps.apple.com/us/app/stathero/id1448391254' ? Share.share(url) : launchUrlHomeBtnGroup(url);
        },
        textColor: txt == 'Invite a friend' ? StatHeroColors.blackSH : StatHeroColors.greyColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(
              color: Colors.grey,
              width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRedBtn({@required String asset}) {

    return SizedBox(
      height: 50,
      width: (getScreenSize(context: context).width / 2) - 30,
      child: FlatButton(
        child: Container( child: Image.asset(asset), height: 20)
         ,
        color: Color.fromARGB(255,234,32,56),
        onPressed: () {
          showBonusDialog(context);
          //showOopsDialog(context); //  opps alert for testing
        },

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(
            color: Colors.grey,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  VoidCallback _NBAClicked(DocumentReference category) {
    return () => moveToScreen(3, category);
  }

  VoidCallback _MLBClicked(DocumentReference category) {
    return () => moveToScreen(6, category);
  }

  VoidCallback _NFLClicked(DocumentReference category) {
    return () => moveToScreen(4, category);
  }

  VoidCallback _PGAClicked(DocumentReference category) {
    return () => moveToScreen(1, category);
  }


  VoidCallback _NascarClicked(DocumentReference category) {
    return () => moveToScreen(2, category);
  }

  VoidCallback _NHLClicked(DocumentReference category) {
    return () => moveToScreen(5, null);
  }

  void moveToScreen(int type, DocumentReference category) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (BuildContext context) {
          return ContestScreen(type: type, category: category);
        },
      ),
    );

  }

  void moveToRivals() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (BuildContext context) {
          return RivalsScreen(category: getRivalsDocumentReferenceFromCategories());
        },
      ),
    );

  }

  void moveToWebViewScreen(String url) {
    launchRulesAndScoringURL();
  }

  Future<void> updateToken(String token) async {
    CollectionReference collectionReference = Firestore.instance.collection("Users");
    Query query = collectionReference.where('email', isEqualTo: user.data.email).limit(1);
    UserData userData;
    //add  details
    query.getDocuments().then((value) {
      value.documents.first.reference.updateData({'fcmToken': token}).then((result){
        print("Fcm token updated");
        // listen fcm token changes only after we updated it, otherwise it will log out everythime after you log in
        user.data.fcmToken = token;
        subscribeToFirebaseUserdataChanges();
      }).catchError((e) {
        print("Error updating fcm token");
        print(e);
        // listen fcm token changes only after we updated it, otherwise it will log out everythime after you log in
        user.data.fcmToken = token;
        subscribeToFirebaseUserdataChanges();

      });
    }).catchError((error) {
      print(error.toString());
    });
  }

  void subscribeToFirebaseUserdataChanges() async => await _getUser().then((FirebaseUser user){
  var currentUserRef = Firestore.instance.collection('Users').where('email', isEqualTo: user.email).limit(1);
  currentUserRef.snapshots().listen((data) {
    data.documentChanges.forEach((DocumentChange change) {
      String fcmToken = change.document.data['fcmToken'];
      var userInfo = jsonDecode(MemoryManagement.getUserInfo());
      var user = AppUser.fromJson(userInfo);
      if(fcmToken != user.data.fcmToken) {
        user.data.fcmToken = fcmToken;
        MemoryManagement.setUserInfo(jsonEncode(user));
        }
      });
    });
  });

  static int currentWeek;

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state == AppLifecycleState.resumed){
    }
  }

  DocumentReference getNASDocumentReferenceFromCategories() {
    for(CategoryData categoryData in categoryDataList){
      if(categoryData.name.contains("nascar") || categoryData.name.contains("Nascar")){
        return categoryData.documentReference;
      }
    }
    return null;
  }


  /** TODO Fix this for all categories*/
  DocumentReference getNFLDocumentRefecrenceFromCategories() {
    for(CategoryData categoryData in categoryDataList){
      if(categoryData.name != null && categoryData.name.contains("nfl") || categoryData.name.contains("NFL")){
        return categoryData.documentReference;
      }
    }
    return null;
  }

  DocumentReference getMLBDocumentRefecrenceFromCategories() {
    for(CategoryData categoryData in categoryDataList){
      if(categoryData.name != null && categoryData.name.contains("mlb") || categoryData.name.contains("MLB")){
        return categoryData.documentReference;
      }
    }
    return null;
  }

  /** TODO Fix this for all categories*/
  DocumentReference getNBADocumentReferenceFromCategories() {
    for(CategoryData categoryData in categoryDataList){
      if(categoryData.name != null && categoryData.name.contains("nba") || categoryData.name.contains("NBA")){
        return categoryData.documentReference;
      }
    }
    return null;
  }

  DocumentReference getRivalsDocumentReferenceFromCategories() {
    for(CategoryData categoryData in categoryDataList){
      if(categoryData.name != null && categoryData.name.contains("Rivals") || categoryData.name.contains("RIVALS")){
        return categoryData.documentReference;
      }
    }
    return null;
  }

  DocumentReference getPGADocumentReferenceFromCategories() {
    for(CategoryData categoryData in categoryDataList){
      if(categoryData.name != null && categoryData.name.contains("pga") || categoryData.name.contains("PGA")){
        return categoryData.documentReference;
      }
    }
    return null;
  }

  List<CategoryData> categoryDataList = [];


  /** TODO Fix this for all categories*/
  Future<List<CategoryData>> getCategories() async {
    //print("get print list called");


    var collectionReference = await Firestore().collection("Categories");
       // .where("enabled",isEqualTo: true);
    QuerySnapshot categoryQuery = await collectionReference.getDocuments();
    //print("categoryQuery----->${categoryQuery.documents}");


    categoryQuery.documents.forEach((DocumentSnapshot documentSnapshot){
      CategoryData category = CategoryData.fromJson(documentSnapshot.data,documentSnapshot.documentID,documentSnapshot.reference);
      categoryDataList.add(category);
    });
    //print("categoryList----->$categoryDataList");
//    final List<CategoryData> categoryList = categoryQuery.documents.map((
//        documentSnapshot) {
//      print("category----->${documentSnapshot.data}");
//      return CategoryData.fromJson(documentSnapshot.data,documentSnapshot.documentID,documentSnapshot.reference);
//    }).toList();
    return categoryDataList;

}





  void _showSuccessLocationVerifiedDialog() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (BuildContext context, _, __) =>
            AlertPage(text: "Your location has been verified successully. You can play now",
            ),
      ),
    );
  }

  bool timeIsLessThan1Hour(locationVerifiedField) {
    try {
      DateTime locationVerifiedDate;
      if(locationVerifiedField is Timestamp) {
        locationVerifiedDate = locationVerifiedField.toDate().toUtc();
      }
      else if(locationVerifiedField is String){
        locationVerifiedDate  = DateTime.parse(locationVerifiedField).toUtc();
      }
      else{
        return false;
      }
      return DateTime
          .now().toUtc()
          .difference(locationVerifiedDate)
          .inMinutes <= 60 ? true : false;
    }
    on Exception catch (e) {
      return false;
    }

  }

  void _showErrorLocationDialog() {
    // flutter defined function
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (BuildContext context, _, __) =>
            AlertPage(text: 'Looks like you are currently out of StatHero\'s geographic area in which you can legally play.',
            ),
      ),
    );
  }


  showBonusDialog(context) => showDialog(context: context, builder: (context) => BonusDialog(inviteFriendDialog));
  showOopsDialog(context) => showDialog(context: context, builder: (context) => OopsDialog());

  void inviteFriendDialog() {
    String url = 'https://stathero.page.link/XwU4wC2HZ8TCL1FU9';
    url == 'https://stathero.page.link/XwU4wC2HZ8TCL1FU9' ? Share.share('${user.data.firstName + ' ' + user.data.lastName} Wants To Invite You To Get In On The Action And Play StatHero. Get \$10 Each On Your First Entry Of \$5 Or More.' + ' ' +url) : moveToWebViewScreen(url);
  }

}