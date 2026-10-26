import 'dart:io' show Platform;

/// What to call the phone's health store in the interface.
///
/// "Health Connect" is Android's; on an iPhone the same thing is Apple Health,
/// and a settings section titled "Health Connect" there names an app the person
/// does not have.
String healthStoreName({bool? ios}) =>
    (ios ?? Platform.isIOS) ? 'Apple Health' : 'Health Connect';
