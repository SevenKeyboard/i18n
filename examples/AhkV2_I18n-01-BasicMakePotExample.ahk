#Requires AutoHotkey v2.0
#SingleInstance Force
#Include "..\AhkV2_I18n.ahk"
#Include ".\lib\ExampleInclude.ahk"

;  makePot scans the script source, so execution order does not matter here.
AhkV2_I18n.makePot()

itemCount  := 3
minutes    := 15
replyCount := 2
likeCount  := 10

__("Settings")
__("Save", "ui")
__("Cancel", "ui")
__("Network error", "errors")

_n("Item", "Items", itemCount)
_n("Minute", "Minutes", minutes, "ui")

_x("Close", "verb", "ui")
_x("Close", "adjective", "ui")

_nx("Reply", "Replies", replyCount, "noun", "forum")
_nx("Like", "Likes", likeCount, "verb", "forum")

/*
This block is included only to make this example self-contained.
In actual use, these functions should be provided by L10nUtils via #Include.

https://github.com/SevenKeyboard/l10n-utils/blob/main-ahkv2.0/lib/L10nUtils.ahk
*/
;@I18n-IgnoreBegin
__(text, domain := "default")    {
}
_n(single, plural, num, domain := "default")    {
}
_x(text, context, domain := "default")    {
}
_nx(single, plural, num, context, domain := "default")    {
}
;@I18n-IgnoreEnd