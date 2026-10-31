import '../manage_imports.dart';

class ChatScreen extends StatefulWidget {
  final UserModel? userData;
  final int ride_id;
  final bool? show_history;

  ChatScreen({this.userData, required this.ride_id, this.show_history});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String id = '';
  var messageCont = TextEditingController();
  var messageFocus = FocusNode();
  bool isMe = false;

  @override
  void initState() {
    super.initState();
    if (widget.show_history == true) {
      chatMessageService = ChatMessageService();
    } else {
      init();
    }
  }

  UserModel sender = UserModel(
    username: sharedPref.getString(USER_NAME),
    profileImage: sharedPref.getString(USER_PROFILE_PHOTO),
    uid: sharedPref.getString(UID),
    playerId: sharedPref.getString(PLAYER_ID),
  );

  init() async {
    id = sharedPref.getString(UID)!;

    chatMessageService = ChatMessageService();
    chatMessageService.setUnReadStatusToTrue(
        riderID: sender.uid!, driverID: widget.userData!.uid.validate());
    setState(() {});
  }

  @override
  void dispose() {
    try {
      chatMessageService.setUnReadStatusToTrue(
          riderID: sender.uid!, driverID: widget.userData!.uid.validate());
    } catch (e) {}
    super.dispose();
  }

  sendMessage() async {
      if (messageCont.text.trim().isEmpty) {
        messageFocus.requestFocus();
        return;
      }
    ChatMessageModel data = ChatMessageModel();
    data.receiverId = widget.userData!.uid;
    data.senderId = sender.uid;
    data.message = messageCont.text;
    data.isMessageRead = false;
    data.msg_topic = widget.ride_id.toString();
    data.createdAt = DateTime.now().millisecondsSinceEpoch;
    data.messageType = MessageType.TEXT.name;
    String f_name = sharedPref.getString(FIRST_NAME) ?? '';
    String l_name = sharedPref.getString(LAST_NAME) ?? '';
    notificationService
        .sendPushNotifications(
            f_name == ''
                ? sharedPref.getString(USER_NAME)!
                : f_name + " $l_name",
            messageCont.text,
            receiverPlayerId: widget.userData!.playerId)
        .catchError(log);
    messageCont.clear();
    setState(() {});
    return await chatMessageService.addMessage(data).then((value) async {

    });
  }

  @override
  Widget build(BuildContext context) {
    // ignore:deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          return true;
        } else {
          launchScreen(getContext, DashBoardScreen(), isNewTask: true);
          return false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    launchScreen(getContext, DashBoardScreen(),
                        isNewTask: true);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              SizedBox(width: 10),
              if (widget.show_history != true)
                ClipRRect(
                    borderRadius: BorderRadius.all(radiusCircular(20)),
                    child: commonCachedNetworkImage(
                        widget.userData!.profileImage.validate(),
                        fit: BoxFit.cover,
                        height: 40,
                        width: 40)),
              // CircleAvatar(backgroundImage: NetworkImage(widget.userData!.profileImage.validate()), minRadius: 20),
              SizedBox(width: 10),
              if (widget.show_history != true)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                      widget.userData!.firstName
                              .validate()
                              .capitalizeFirstLetter() +
                          " ${widget.userData!.lastName.validate()}",
                      style: TextStyle(color: Colors.white)),
                ),
              if (widget.show_history == true)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("${language.lblRide} #${widget.ride_id} Messages",
                      style: boldTextStyle(color: Colors.white)),
                ),
            ],
          ),
          backgroundColor: primaryColor,
        ),
        body: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: Stack(
            children: [
              Container(
                padding: EdgeInsets.only(
                    bottom: widget.show_history == true ? 20 : 76),
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                child: PaginateFirestore(
                  reverse: true,
                  isLive: true,
                  padding:
                      EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 0),
                  physics: BouncingScrollPhysics(),
                  query: widget.show_history == true
                      ? chatMessageService
                          .rideSpecificChatMessagesWithPagination(
                              rideId: widget.ride_id.toString())
                      : chatMessageService.chatMessagesWithPagination(
                          riderId: sharedPref.getString(UID),
                          driverID: widget.userData!.uid.validate(),
                          filter_msg: widget.ride_id),
                  itemsPerPage: PER_PAGE_CHAT_COUNT,
                  shrinkWrap: true,
                  onEmpty: Offstage(),
                  itemBuilderType: PaginateBuilderType.listView,
                  itemBuilder: (context, snap, index) {
                    ChatMessageModel data = ChatMessageModel.fromJson(
                        snap[index].data() as Map<String, dynamic>);
                    data.isMe = data.senderId == sender.uid;
                    return ChatItemWidget(
                        data: data,
                        historyModeOnly: widget.show_history == true);
                  },
                ),
              ),
              if (widget.show_history != true)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Visibility(
                    visible: widget.show_history == true ? false : true,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: radius(),
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            spreadRadius: 0.5,
                            blurRadius: 0.5,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.only(left: 8, right: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: messageCont,
                              decoration: InputDecoration(
                                focusColor: primaryColor,
                                border: InputBorder.none,
                                hintText: language.writeMessage,
                                hintStyle: secondaryTextStyle(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 8),
                              ),
                              cursorColor: appStore.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                              focusNode: messageFocus,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              minLines: 1,
                              style: primaryTextStyle(),
                              textInputAction: mIsEnterKey
                                  ? TextInputAction.send
                                  : TextInputAction.newline,
                              onSubmitted: (s) {
                                sendMessage();
                              },
                              cursorHeight: 20,
                              maxLines: 5,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.send, color: primaryColor),
                            onPressed: () {
                              sendMessage();
                            },
                          )
                        ],
                      ),
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
