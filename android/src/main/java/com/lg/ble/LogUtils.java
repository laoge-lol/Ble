package com.lg.ble;

import android.util.Log;

/**
 * 日志管理工具
 */
public class LogUtils {

    //各种打印
    public static boolean isDebug = true;  //是否需要打印bug,可以在application的onCreate函数里面初始化
    private static String TAG = "tzz";
    private static final int STRING_MAXLENGTH = 1000; //Log单行的最大长度
    private static int STRING_START = 0;
    private static int STRING_END = 1000;

    private static final int Level_Verbose = 1;
    private static final int Level_Info = 2;
    private static final int Level_Debug = 3;
    private static final int Level_Warn = 4;
    private static final int Level_Error = 5;

    public static void setDebug(boolean bool) {
        isDebug = bool;
    }

    // 下面四个是默认tag的函数
    public static void i(String msg) {
        handleMessage(Level_Info, TAG, msg);
    }

    public static void d(String msg) {
        handleMessage(Level_Debug, TAG, msg);
    }

    public static void e(String msg) {
        handleMessage(Level_Error, TAG, msg);
    }

    public static void v(String msg) {
        handleMessage(Level_Verbose, TAG, msg);
    }

    public static void w(String msg) {
        handleMessage(Level_Warn, TAG, msg);
    }

    // 下面是传入自定义tag的函数
    public static void i(String tag, String msg) {
        handleMessage(Level_Info, tag, msg);
    }

    public static void d(String tag, String msg) {
        handleMessage(Level_Debug, tag, msg);
    }

    public static void e(String tag, String msg) {
        handleMessage(Level_Error, tag, msg);
    }

    public static void v(String tag, String msg) {
        handleMessage(Level_Verbose, tag, msg);
    }

    public static void w(String tag, String msg) {
        handleMessage(Level_Warn, tag, msg);
    }

    public static void handleMessage(int level, String tag, String message) {
        synchronized ("txwatch"){
            if (isDebug) {
                int msg_difference = message.length() - STRING_MAXLENGTH;
                if (msg_difference > 0) {
                    STRING_END = STRING_MAXLENGTH;
                    for (; ; ) {
                        if (STRING_END >= message.length()) {
                            showLog(level, TAG, message.substring(STRING_START));
                            //解决共用时造成下标溢出
                            STRING_START=0;
                            STRING_END=1000;
                            return;
                        }
                        showLog(level, tag, message.substring(STRING_START, STRING_END));
                        STRING_START = STRING_END;
                        STRING_END += STRING_MAXLENGTH;
                    }
                } else {
                    showLog(level, tag, message);
                }

            }
        }
    }

    private static void showLog(int level, String tag, String message) {
        switch (level) {
            case Level_Verbose:
                Log.v(tag, message);
                break;
            case Level_Debug:
                Log.d(tag, message);
                break;
            case Level_Info:
                Log.i(tag, message);
                break;
            case Level_Warn:
                Log.w(tag, message);
                break;
            case Level_Error:
                Log.e(tag, message);
                break;
            default:
                break;
        }

    }


}