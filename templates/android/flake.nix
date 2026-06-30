{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        platformVersion = "36";
        buildToolsVersion = "36.0.0";
        systemImageType = "google_apis";
        abiVersion = "x86_64";
        systemImagePackage = "system-images;android-${platformVersion};${systemImageType};${abiVersion}";

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ platformVersion ];
          buildToolsVersions = [ buildToolsVersion ];
          includeEmulator = "if-supported";
          includeSystemImages = true;
          includeCmake = false;
          includeNDK = false;
          includeSources = true;
          systemImageTypes = [ systemImageType ];
          abiVersions = [ abiVersion ];
        };

        androidSdk = androidComposition.androidsdk;
      in
      {
        devShells.default = pkgs.mkShell rec {
          JAVA_HOME = pkgs.jdk21.home;
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          ANDROID_SDK_ROOT = ANDROID_HOME;
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_HOME}/build-tools/${buildToolsVersion}/aapt2";

          packages = with pkgs; [
            gradle
            git
            jdk21
            kotlin-language-server
            android-tools

            (pkgs.writeShellScriptBin "create-avd" ''
              set -eu

              avd_name="''${1:-compose-api${platformVersion}}"
              avd_home="''${ANDROID_AVD_HOME:-$HOME/.android/avd}"

              mkdir -p "$avd_home"

              if [ -d "$avd_home/$avd_name.avd" ]; then
                echo "AVD already exists: $avd_name"
                exit 0
              fi

              printf 'no\n' | avdmanager create avd \
                --name "$avd_name" \
                --package "${systemImagePackage}"
            '')

            (pkgs.writeShellScriptBin "run-emulator" ''
              set -eu

              avd_name="''${1:-compose-api${platformVersion}}"
              if [ "$#" -gt 0 ]; then
                shift
              fi

              avd_home="''${ANDROID_AVD_HOME:-$HOME/.android/avd}"
              if [ ! -d "$avd_home/$avd_name.avd" ]; then
                create-avd "$avd_name"
              fi

              exec emulator -avd "$avd_name" "$@"
            '')

            (pkgs.writeShellScriptBin "init" ''
              set -eu

              if [ -d .git ]; then
                echo "Refusing to initialize: .git already exists" >&2
                exit 1
              fi

              project_name="$(basename "$PWD" | tr '[:upper:] _' '[:lower:]--')"
              package_suffix="$(printf '%s' "$project_name" | tr '-' '_' | tr -c '[:alnum:]_' '_' | sed 's/^_*//; s/_*$//')"
              case "$package_suffix" in
                [0-9]*|"") package_suffix="app_$package_suffix" ;;
              esac
              package_name="''${1:-com.example.$package_suffix}"

              package_dir="app/src/main/kotlin/$(printf '%s' "$package_name" | tr . /)"

              mkdir -p \
                "$package_dir" \
                app/src/main/res/values \
                gradle

              cat > settings.gradle.kts <<EOF
              pluginManagement {
                  repositories {
                      google()
                      mavenCentral()
                      gradlePluginPortal()
                  }
              }

              dependencyResolutionManagement {
                  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
                  repositories {
                      google()
                      mavenCentral()
                  }
              }

              rootProject.name = "$project_name"
              include(":app")
              EOF

              cat > build.gradle.kts <<EOF
              plugins {
                  alias(libs.plugins.android.application) apply false
                  alias(libs.plugins.kotlin.android) apply false
                  alias(libs.plugins.kotlin.compose) apply false
              }
              EOF

              cat > gradle/libs.versions.toml <<EOF
              [versions]
              agp = "8.13.2"
              kotlin = "2.4.0"
              activityCompose = "1.12.4"
              composeBom = "2026.02.01"
              coreKtx = "1.18.0"
              lifecycleRuntimeKtx = "2.10.0"

              [libraries]
              androidx-activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
              androidx-compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
              androidx-compose-material3 = { group = "androidx.compose.material3", name = "material3" }
              androidx-compose-ui = { group = "androidx.compose.ui", name = "ui" }
              androidx-compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
              androidx-compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
              androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }
              androidx-lifecycle-runtime-ktx = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version.ref = "lifecycleRuntimeKtx" }

              [plugins]
              android-application = { id = "com.android.application", version.ref = "agp" }
              kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
              kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
              EOF

              cat > app/build.gradle.kts <<EOF
              plugins {
                  alias(libs.plugins.android.application)
                  alias(libs.plugins.kotlin.android)
                  alias(libs.plugins.kotlin.compose)
              }

              android {
                  namespace = "$package_name"
                  compileSdk = 36
                  buildToolsVersion = "36.0.0"

                  defaultConfig {
                      applicationId = "$package_name"
                      minSdk = 26
                      targetSdk = 36
                      versionCode = 1
                      versionName = "0.1.0"
                  }

                  buildTypes {
                      release {
                          isMinifyEnabled = false
                          proguardFiles(
                              getDefaultProguardFile("proguard-android-optimize.txt"),
                              "proguard-rules.pro",
                          )
                      }
                  }

                  compileOptions {
                      sourceCompatibility = JavaVersion.VERSION_17
                      targetCompatibility = JavaVersion.VERSION_17
                  }

                  buildFeatures {
                      compose = true
                  }
              }

              kotlin {
                  compilerOptions {
                      jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                  }
              }

              dependencies {
                  implementation(libs.androidx.activity.compose)
                  implementation(libs.androidx.core.ktx)
                  implementation(libs.androidx.lifecycle.runtime.ktx)
                  implementation(platform(libs.androidx.compose.bom))
                  implementation(libs.androidx.compose.material3)
                  implementation(libs.androidx.compose.ui)
                  implementation(libs.androidx.compose.ui.tooling.preview)
                  debugImplementation(libs.androidx.compose.ui.tooling)
              }
              EOF

              cat > app/src/main/AndroidManifest.xml <<EOF
              <manifest xmlns:android="http://schemas.android.com/apk/res/android">
                  <application
                      android:allowBackup="true"
                      android:label="@string/app_name"
                      android:supportsRtl="true"
                      android:theme="@style/Theme.App">
                      <activity
                          android:name=".MainActivity"
                          android:exported="true">
                          <intent-filter>
                              <action android:name="android.intent.action.MAIN" />
                              <category android:name="android.intent.category.LAUNCHER" />
                          </intent-filter>
                      </activity>
                  </application>
              </manifest>
              EOF

              cat > "$package_dir/MainActivity.kt" <<EOF
              package $package_name

              import android.os.Bundle
              import androidx.activity.ComponentActivity
              import androidx.activity.compose.setContent
              import androidx.activity.enableEdgeToEdge
              import androidx.compose.foundation.layout.Arrangement
              import androidx.compose.foundation.layout.Column
              import androidx.compose.foundation.layout.fillMaxSize
              import androidx.compose.foundation.layout.padding
              import androidx.compose.material3.Button
              import androidx.compose.material3.MaterialTheme
              import androidx.compose.material3.Scaffold
              import androidx.compose.material3.Surface
              import androidx.compose.material3.Text
              import androidx.compose.runtime.Composable
              import androidx.compose.runtime.getValue
              import androidx.compose.runtime.mutableIntStateOf
              import androidx.compose.runtime.saveable.rememberSaveable
              import androidx.compose.runtime.setValue
              import androidx.compose.ui.Alignment
              import androidx.compose.ui.Modifier
              import androidx.compose.ui.tooling.preview.Preview

              class MainActivity : ComponentActivity() {
                  override fun onCreate(savedInstanceState: Bundle?) {
                      super.onCreate(savedInstanceState)
                      enableEdgeToEdge()
                      setContent {
                          App()
                      }
                  }
              }

              @Composable
              private fun App() {
                  MaterialTheme {
                      Scaffold { innerPadding ->
                          Surface(
                              modifier = Modifier
                                  .fillMaxSize()
                                  .padding(innerPadding),
                              color = MaterialTheme.colorScheme.background,
                          ) {
                              HomeScreen()
                          }
                      }
                  }
              }

              @Composable
              private fun HomeScreen() {
                  var count by rememberSaveable { mutableIntStateOf(0) }

                  Column(
                      modifier = Modifier.fillMaxSize(),
                      horizontalAlignment = Alignment.CenterHorizontally,
                      verticalArrangement = Arrangement.Center,
                  ) {
                      Text(
                          text = "Hello from $project_name",
                          style = MaterialTheme.typography.headlineMedium,
                      )
                      Button(onClick = { count += 1 }) {
                          Text("Clicks: " + count)
                      }
                  }
              }

              @Preview(showBackground = true)
              @Composable
              private fun AppPreview() {
                  App()
              }
              EOF

              cat > app/src/main/res/values/strings.xml <<EOF
              <resources>
                  <string name="app_name">$project_name</string>
              </resources>
              EOF

              cat > app/src/main/res/values/styles.xml <<EOF
              <resources>
                  <style name="Theme.App" parent="android:style/Theme.Material.Light.NoActionBar">
                      <item name="android:windowNoTitle">true</item>
                  </style>
              </resources>
              EOF

              cat > gradle.properties <<EOF
              android.useAndroidX=true
              org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
              org.gradle.parallel=true
              org.gradle.configuration-cache=true
              EOF

              cat > local.properties <<EOF
              sdk.dir=$ANDROID_HOME
              EOF

              touch app/proguard-rules.pro

              git init
              git add .
              git commit -m "Initial commit"
            '')
          ];

          shellHook = ''
            export ANDROID_AVD_HOME="''${ANDROID_AVD_HOME:-$HOME/.android/avd}"
            for android_tool_dir in "$ANDROID_HOME/tools/bin" "$ANDROID_HOME/cmdline-tools/"*/bin; do
              if [ -d "$android_tool_dir" ]; then
                export PATH="$android_tool_dir:$PATH"
              fi
            done
            export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
          '';
        };
      }
    );
}
