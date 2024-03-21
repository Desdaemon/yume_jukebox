# yume_jukebox

Yume 2kki's Music Room on the go.

<img src="https://github.com/Desdaemon/yume_jukebox/assets/36768030/10bf1ff1-c787-433d-be7a-f861d15bc441" width="400" alt="A preview of the app, showing the track played in Eyeball Cherry Field alongside its panorama.">

## Usage

This app does not come with tracks or graphics by default; please import those files into `images` and `music`
and fill out `lib/manifest.dart` to enumerate them. Once done, you can run `flutter build apk` and `flutter install` to
install the app.

Once the app is in a more polished state, a script will be available to automatically extract the files needed from your
local Yume 2kki installation.
