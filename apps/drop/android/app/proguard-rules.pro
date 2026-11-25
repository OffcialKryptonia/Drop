-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.PaymentsClient
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.Wallet
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.WalletUtils
-dontwarn com.google.crypto.tink.subtle.Ed25519Sign$KeyPair
-dontwarn com.google.crypto.tink.subtle.Ed25519Sign
-dontwarn com.google.crypto.tink.subtle.Ed25519Verify
-dontwarn com.google.crypto.tink.subtle.X25519
-dontwarn com.stripe.android.pushProvisioning.EphemeralKeyUpdateListener
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers
# In-app calling (Agora and LiveKit/WebRTC use reflection and JNI)
-keep class io.agora.** { *; }
-dontwarn io.agora.**
-keep class org.webrtc.** { *; }
-keep class io.livekit.** { *; }
-dontwarn org.webrtc.**
# androidx.window looks for optional vendor classes (foldables) that only exist on some phones; R8 must not fail on them
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**
# R8 stops with "EnclosingMethod requires InnerClasses attribute" unless both are kept
-keepattributes InnerClasses,EnclosingMethod,Signature,*Annotation*
# TEMPORARY diagnostic: writes the merged R8 configuration so the failing rule can be found
-printconfiguration r8-merged-config.txt
