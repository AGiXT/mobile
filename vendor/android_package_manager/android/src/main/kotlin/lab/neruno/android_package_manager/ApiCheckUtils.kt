package lab.neruno.android_package_manager

import android.os.Build
import androidx.annotation.ChecksSdkIntAtLeast

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.LOLLIPOP_MR1)
fun isAtLeastAndroid22(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.M)
fun isAtLeastAndroid23(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.N)
fun isAtLeastAndroid24(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.N
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.O)
fun isAtLeastAndroid26(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.O_MR1)
fun isAtLeastAndroid27(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.P)
fun isAtLeastAndroid28(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.Q)
fun isAtLeastAndroid29(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.R)
fun isAtLeastAndroid30(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.S)
fun isAtLeastAndroid31(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.S_V2)
fun isAtLeastAndroid32(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S_V2
}

@ChecksSdkIntAtLeast(api = Build.VERSION_CODES.TIRAMISU)
fun isAtLeastAndroid33(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
}