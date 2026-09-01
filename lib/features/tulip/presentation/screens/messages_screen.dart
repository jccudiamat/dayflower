import 'package:flutter/material.dart';

import '../widgets/share_your_day.dart';

/// The Camera tab. Nothing but the viewfinder.
///
/// This was the Messages inbox until 2026-09-02, when Flowers got its own
/// tab pointing straight at the conversation. The class name and the route
/// (`Routes.flowers`) still say "messages"; renaming them would touch the
/// router, the nav and every deep link for no behavioural gain.
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // No header, no SafeArea at the top: the viewfinder runs under the
    // status bar the way every camera does. The close button and the "My
    // Day" title moved inside the frame, where they sit over the picture
    // instead of pushing it down the screen.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: ShareYourDayBar(),
    );
  }
}
