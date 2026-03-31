;@I18n-IgnoreFile
#Requires AutoHotkey v1.1.35+
;==============================================================
; AhkV1_I18n — A toolkit for gettext-style internationalization workflows
;
; GitHub: https://github.com/SevenKeyboard/i18n
; Author: SevenKeyboard Ltd. (2026)
; License: MIT License
;
; Documentation / References:
;   AhkV1_publishCompiledTranslationsToRuntimeLocale.ahk
;     https://github.com/SevenKeyboard/publish-compiled-translations-to-runtime-locale/blob/main/AhkV1_publishCompiledTranslationsToRuntimeLocale.ahk
;
;   L10nUtils
;     https://github.com/SevenKeyboard/l10n-utils
;==============================================================

/*
Example Usage:

    This function is designed to be placed in the user library
    (or standard library) and called from the main script that
    publishes compiled translations for localization.

    During normal use, leave the call commented out.
    Uncomment it only when publishing compiled translations.

    ;  #Include <AhkV1_I18n>
    ;  AhkV1_I18n.makePot()
*/

/*
%A_MyDocuments%\
└─ AutoHotkey\
   └─ lib\
      └─ AhkV1_I18n.ahk
my-app\
├─ MyApp.ahk
└─ languages\
   ├─ default\
   │  ├─ messages.pot
   │  ├─ en_US.po
   │  ├─ en_US.mo
   │  ├─ es_ES.po
   │  ├─ es_ES.mo
   │  ├─ ja.po
   │  ├─ ja.mo
   │  └─ ...
   ├─ extra\
   │  ├─ messages.pot
   │  ├─ en_US.po
   │  ├─ en_US.mo
   │  ├─ es_ES.po
   │  ├─ es_ES.mo
   │  ├─ ja.po
   │  ├─ ja.mo
   │  └─ ...
   └─ ...
*/

class VersionManager_AhkV1_I18n
{
    static _ := VersionManager_AhkV1_I18n._init()
    _init()    {
        global
        AhkV1_I18N_VERSION := AhkV1_I18n.Version
    }
}
class AhkV1_I18n
{
    Version    {
        get  {
            return "0.0.0"
        }   
    }
    makePot(cmdLine := "")    { ;  https://developer.wordpress.org/cli/commands/i18n/make-pot/
        args := cmdLine !== "" ? this._commandLineToArgvW(cmdLine) : []
        positionals := []
        options := object("location",true), parsingOptions := true
        for _,arg in args    {
            if (parsingOptions && subStr(arg, 1, 2) == "--")    {
                if (arg == "--")    {
                    parsingOptions := false
                }  else if (true)    {
                    ;  Not implemented yet
                    ;
                    ;  --headers=<headers>
                    ;  --location
                    ;  --no-location
                    ;  --file-comment=<file-comment>
                    ;  --package-name=<name>
                    ;
                    ;  --merge
                    ;  --no-merge
                }
                continue
            }
            if (2 <= positionals.length())
                throw exception("Parameter #1 of AhkV1_I18n.makePot must not contain more than 2 positional arguments.", -1)
            positionals.push(arg)
        }
        ;----------------------------------
        rootScriptPath  := positionals.hasKey(1) ? this._getFullPathName(positionals[1]) : A_ScriptFullPath
        splitPath rootScriptPath, rootScriptName, rootScriptDir
        ctx := {rootScriptPath:rootScriptPath
            ,rootScriptName:rootScriptName
            ,rootScriptDir:rootScriptDir}
        state := {visitedPaths:object()
            ,messagesByKey:object()}
        prevIsCritical := A_IsCritical
        critical % "On"
        try  {
            this._scanScriptFile(rootScriptPath, ctx, state)
        }  finally  {
            critical % prevIsCritical
        }
        /*
        for msgKey,message in state.messagesByKey    {
            outputDebug % "callType: " . message.callType
            outputDebug % "reference: "
            for j,reference in message.references
                outputDebug % "    " . reference.file . "#L" . reference.line
            for name,prop in message    {
                if (name == "callType" || name == "references" || name == "_referenceKeys")
                    continue
                outputDebug % name . " :" . prop
            }
            outputDebug % "----------------------------------"
        }
        */
        ;----------------------------------
        languagesDir := positionals.hasKey(2) ? this._getFullPathName(positionals[2]) : rootScriptDir . "\languages"
        messagesByDomain := this._buildMessagesByDomain(state)
        for domainName,messages in messagesByDomain    {
            domainDir   := languagesDir . "\" . domainName
            potFilePath := domainDir . "\messages.pot"
            fileCreateDir % domainDir
            try  {
                fileDelete % potFilePath
            }
            fileAppend % this._buildPot(messages, options), % potFilePath, % "UTF-8-RAW"
        }
    }
    ;---------------------------------------------------------------------
    _buildMessagesByDomain(state)    {
        messagesByDomain := object()
        for _,message in state.messagesByKey    {
            domainName := message.domain
            if (!messagesByDomain.hasKey(domainName))
                messagesByDomain[domainName] := []
            messagesByDomain[domainName].push(message)
        }
        return messagesByDomain
    }
    _buildPot(messages, options := "")    {
        pot := this._buildPotHeader(options)
        for _,message in messages
            pot .= "`r`n`r`n" . this._buildPotEntry(message, options)
        return pot
    }
    _buildPotHeader(options := "")    {
        return format("
(Join`r`n RTrim0
msgid """"
msgstr """"
""PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n""
""Last-Translator: FULL NAME <EMAIL@ADDRESS>\n""
""Language-Team: LANGUAGE <LL@li.org>\n""
""X-Generator: AhkV1_I18n {1}\n""
)", this.Version)
    }
    _buildPotEntry(message, options := "")    {
        entry := ""
        if (options !== "" && options.hasKey("location") && options["location"])    {
            for _,reference in message.references
                entry .= "#: " . reference.file . ":" . reference.line . "`r`n"
        }
        if (message.hasKey("msgctxt"))
            entry .= "msgctxt " . this._escapePotString(message.msgctxt) . "`r`n"
        entry .= "msgid " . this._escapePotString(message.msgid) . "`r`n"
        if (message.hasKey("msgidPlural"))    {
            entry .= "msgid_plural " . this._escapePotString(message.msgidPlural) . "`r`n"
            entry .= "msgstr[0] """"`r`n"
            entry .= "msgstr[1] """""
        }  else  {
            entry .= "msgstr """""
        }
        return entry
    }
    _escapePotString(str)    {
        str := strReplace(str, "`r`n", "`n")
        str := strReplace(str, "`r", "`n")
        str := strReplace(str, "\", "\\")
        str := strReplace(str, """", "\""")
        return inStr(str, "`n")
            ? ("""""`r`n""" . strReplace(str, "`n", "\n""`r`n""") . """")
            : ("""" . str . """")
    }
    ;---------------------------------------------------------------------
    _scanScriptFile(scriptFullPath, ctx, state)    {
        if (state.visitedPaths.hasKey(scriptFullPath))
            return
        state.visitedPaths[scriptFullPath] := true
        ;----------------------------------
        fileText := this._readUtf8TextFile(scriptFullPath)
        if (fileText == "")
            return
        if (this._shouldIgnoreFile(fileText))
            return
        ;----------------------------------
        result := this._collectIncludeSpecsAndMessages(fileText, scriptFullPath, ctx, state)
        ;----------------------------------
        includePaths := this._resolveIncludeSpecs(result.includeSpecs, scriptFullPath, ctx)
        for _,path in includePaths
            this._scanScriptFile(path, ctx, state)
    }
    _shouldIgnoreFile(byRef fileText)    {
        loop Parse, % fileText, % "`n", % "`r"
        {
            trimmedLine := trim(A_LoopField)
            if (trimmedLine == "")    {
                continue
            }  else if (subStr(trimmedLine, 1, 1) == "#")    {
                continue
            }  else if (regExMatch(trimmedLine, "iO)\A;@I18n-(.*)", m))    {
                if (m[1] = "IgnoreFile")
                    return true
                continue
            }
            break
        }
        return false
    }
    _collectIncludeSpecsAndMessages(byRef fileText, scriptFullPath, ctx, state)    {
        inBlockComment  := false
        ignoreBlock     := false
        skipNextLine    := false
        inLiteral               := false
        inContinuationLiteral   := false
        stringQuoteChar         := ""
        skipNextChar            := false
        includeSpecs := []
        loop Parse, % fileText, % "`n", % "`r"
        {
            ;----------------------------------
            lineNumber := A_Index
            trimmedLine := trim(A_LoopField)
            skipThisLine := skipNextLine, skipNextLine := false
            isBlockCommentStart := !!(trimmedLine ~= "\A/\*")
            isBlockCommentEnd   := !!(trimmedLine ~= "\*/\z")
            if (isBlockCommentStart)    {
                inBlockComment := !isBlockCommentEnd
                continue
            }
            if (inBlockComment)    {
                if (isBlockCommentEnd)
                    inBlockComment := false
                continue
            }
            if (regExMatch(trimmedLine, "iO)\A;@I18n-(.*)", m))    {
                if (m[1] = "IgnoreBegin")
                    ignoreBlock := true
                else if (m[1] = "IgnoreEnd")
                    ignoreBlock := false
                else if (m[1] = "IgnoreLine")
                    skipNextLine := true
                continue
            }
            if (ignoreBlock)
                continue
            if (skipThisLine)
                continue
            ;----------------------------------
            currLine := A_LoopField
            maskedLine := ""
            if (inContinuationLiteral)    {
                if !(currLine ~= "\A[ `t]*\)")
                    continue
            }
            prevChar:= currChar:= ""
            loop parse, % currLine
            {
                prevChar := currChar
                currChar := A_LoopField
                if (inContinuationLiteral)    {
                    /*
                    In continuation literal mode, only lines starting with ")" are examined.
                    Such a closing line is assumed to contain the matching quote later on.
                    */
                    if (currChar == stringQuoteChar)    {
                        inLiteral := false
                        inContinuationLiteral := false
                        stringQuoteChar := ""
                    }
                    maskedLine .= A_Space
                    continue
                }
                ;----------------------------------
                if (skipNextChar)    {
                    skipNextChar := false
                    maskedLine .= A_Space
                    continue
                }
                if (inLiteral)    {
                    if (currChar == "``")    {
                        skipNextChar := true
                        maskedLine .= A_Space
                        continue
                    }
                    if (currChar == stringQuoteChar)    {
                        nextChar := subStr(A_LoopField, A_Index, 1)
                        if (nextChar == stringQuoteChar)    {
                            skipNextChar := true
                            maskedLine .= A_Space
                            continue
                        }
                        inLiteral := false
                        stringQuoteChar := ""
                        maskedLine .= currChar
                        continue
                    }
                    maskedLine .= A_Space
                    continue
                }
                if (currChar == """")    {
                    inLiteral := true
                    stringQuoteChar := currChar
                    maskedLine .= currChar
                    continue
                }
                ;----------------------------------
                if (currChar == ";")    {
                    if (prevChar == "" || prevChar == A_Space || prevChar == A_Tab)
                        break
                }
                if (currChar == "#")    {
                    if (regExMatch(currLine, "iO)\A[ `t]*#Include(?:Again)?[ `t]+\K.+", m))    {
                        spec := rTrim(regExReplace(m[0], "(?<=[ `t]);.*"))
                        includeSpecs.push(spec)
                        maskedLine := ""
                        break
                    }
                    maskedLine .= currChar
                    continue
                }
                maskedLine .= currChar
            }
            if (inLiteral)    {
                /*
                If a quoted literal remains open at end of line,
                treat following lines as a continuation literal until a line starting with ")" closes it.
                */
                inContinuationLiteral := true
            }
            if (maskedLine == "")
                continue
            ;----------------------------------
            this.maskedLineMatches := []
            regExMatch(maskedLine, "O)(?<![.0-9A-Z_a-z[:^ascii:]])"
                . "(?i)(_(?:_|nx?|x))"
                . "\((.+?)\)(?Ci18nMaskedLineRegexCallout_3EB975B3)")
            for i,v in this.maskedLineMatches    {
                rawMaskedArgs := []
                nestingCloser := ""
                nestingOpener := ""
                nestingDepth := 0
                w2 := ""
                for _,w1 in strSplit(v.match[2], ",")    {
                    w2 .= (w2 !== "" ? "," : "") . w1
                    if (nestingDepth == 0)    {
                        if (regExMatch(w1, "O)[(\[{]", m))    {
                            nestingOpener := m[0]
                            nestingCloser := (m[0] == "(" ? ")" : m[0] == "[" ? "]" : "}")
                            regExReplace(w1, "\Q" . nestingOpener . "\E",, openCount)
                            regExReplace(w1, "\Q" . nestingCloser . "\E",, closeCount)
                            nestingDepth := openCount - closeCount
                        }
                    }  else  {
                        regExReplace(w1, "\Q" . nestingOpener . "\E",, openCount)
                        regExReplace(w1, "\Q" . nestingCloser . "\E",, closeCount)
                        nestingDepth += openCount - closeCount
                    }
                    if (nestingDepth < 0)
                        continue 2
                    if (nestingDepth == 0)    {
                        rawMaskedArgs.push(w2), w2 := ""
                        nestingOpener := ""
                        nestingCloser := ""
                        nestingDepth := 0
                    }
                }
                if (nestingDepth !== 0)
                    continue
                ;----------------------------------
                callType := format(v.match[1], "{:L}")
                switch callType
                {
                    case "__":      requiredParamCount := 1
                    case "_n":      requiredParamCount := 3
                    case "_x":      requiredParamCount := 2
                    case "_nx":     requiredParamCount := 4
                    default:        continue
                }
                if (rawMaskedArgs.length() < requiredParamCount || requiredParamCount + 1 < rawMaskedArgs.length())
                    continue
                for j,rawMaskedArg in rawMaskedArgs    {
                    if (j == 3 && (callType == "_n" || callType == "_nx")) ;  num
                        continue
                    if !(rawMaskedArg ~= "\A[ \t]*([""]) *\g{1}[ \t]*\z")
                        continue 2
                }
                ;----------------------------------
                rawArgs := []
                rawArgSlice := subStr(currLine
                    ,v.foundPos + (tp := strLen(callType)) + 1
                    ,v.match.len(0) - tp - 2)
                pos := 1
                len := 0
                for _,rawMaskedArg in rawMaskedArgs    {
                    len := strLen(rawMaskedArg)
                    rawArgs.push(trim(subStr(rawArgSlice, pos, len)))
                    pos += len + 1
                }
                args := []
                domainName := ""
                for j,rawArg in rawArgs    {
                    args.push(tp := this._parseIfAhkStringLiteral(rawArg))
                    if (j == requiredParamCount + 1)    {
                        domainName := format(tp, "{:L}")
                        if (!this._isValidDomainDirName(domainName))
                            continue 2
                    }
                }
                if (domainName == "")
                    args.push(domainName := "default")
                ;----------------------------------
                switch (callType)
                {
                    case "__":
                        text    := args[1]
                        domain  := domainName ;  args[2]
                        msgKey  := callType . "`n" . text . "`n" . domain
                    case "_n":
                        single  := args[1]
                        plural  := args[2]
                        domain  := domainName ;  args[4]
                        msgKey  := callType . "`n" . single . "`n" . plural . "`n" . domain
                    case "_x":
                        text    := args[1]
                        context := args[2]
                        domain  := domainName ;  args[3]
                        msgKey  := callType . "`n" . text . "`n" . context . "`n" . domain
                    case "_nx":
                        single  := args[1]
                        plural  := args[2]
                        context := args[4]
                        domain  := domainName ;  args[5]
                        msgKey  := callType . "`n" . single . "`n" . plural . "`n" . context . "`n" . domain
                }
                msgKey := this._encodeAllChars(msgKey)
                if (!state.messagesByKey.hasKey(msgKey))    {
                    state.messagesByKey[msgKey] := {callType:callType, references:[], _referenceKeys:object()}
                    switch (callType)
                    {
                        case "__":
                            state.messagesByKey[msgKey].msgid       := text
                            state.messagesByKey[msgKey].domain      := domain
                        case "_n":
                            state.messagesByKey[msgKey].msgid       := single
                            state.messagesByKey[msgKey].msgidPlural := plural
                            state.messagesByKey[msgKey].domain      := domain
                        case "_x":
                            state.messagesByKey[msgKey].msgid       := text
                            state.messagesByKey[msgKey].msgctxt     := context
                            state.messagesByKey[msgKey].domain      := domain
                        case "_nx":
                            state.messagesByKey[msgKey].msgid       := single
                            state.messagesByKey[msgKey].msgidPlural := plural
                            state.messagesByKey[msgKey].msgctxt     := context
                            state.messagesByKey[msgKey].domain      := domain
                    }
                }
                refKey := scriptFullPath . "#L" . lineNumber
                if (!state.messagesByKey[msgKey]._referenceKeys.hasKey(refKey))    {
                    state.messagesByKey[msgKey]._referenceKeys[refKey] := true
                    state.messagesByKey[msgKey].references.push({file:scriptFullPath, line:lineNumber})
                }
            }
        }
        return {includeSpecs:includeSpecs}
    }
    _resolveIncludeSpecs(includeSpecs, scriptFullPath, ctx)    {
        includePaths := []
        prevWorkingDir := A_WorkingDir
        try  {
            splitPath scriptFullPath,, includeBaseDir
            setWorkingDir % includeBaseDir
            for _,spec in includeSpecs
            {
                path := ""
                spec := strReplace(spec, "``;", ";")
                if (regExMatch(spec, "O)\A<(.+)>\z", m))    {
                    libName := regExReplace(m[2], "i)\A\*i[ `t]")
                    path := this._resolveLibIncludeSpec(libName, ctx)
                }  else  {
                    fileOrDirName := regExReplace(spec, "i)\A\*i[ `t]")
                    this._deref(fileOrDirName, scriptFullPath, ctx)
                    path := this._getFullPathName(fileOrDirName)
                    if (inStr(fileExist(path), "D"))    {
                        setWorkingDir % path
                        continue
                    }
                }
                if (path !== "")
                    includePaths.push(path)
            }
        }  finally  {
            setWorkingDir % prevWorkingDir
        }
        return includePaths
    }
    _resolveLibIncludeSpec(libName, ctx)    {
        splitPath A_AhkPath,, ahkDir
        searchDirs := [ctx.rootScriptDir . "\Lib"
            ,A_MyDocuments . "\AutoHotkey\Lib"
            ,ahkDir . "\Lib"]
        fallbackLibName := regExMatch(libName, "O)\A([^_]+)_", m) ? m[1] : ""
        for _,dir in searchDirs    {
            candidate := this._getFullPathName(dir . "\" . libName . ".ahk")
            attr := fileExist(candidate)
            if (attr && !inStr(attr, "D"))
                return candidate
            if (fallbackLibName)    {
                candidate := this._getFullPathName(dir . "\" . fallbackLibName . ".ahk")
                attr := fileExist(candidate)
                if (attr && !inStr(attr, "D"))
                    return candidate
            }
        }
        return ""
    }
    _parseIfAhkStringLiteral(rawArg)    {
        if (!regExMatch(rawArg, "O)\A([""])([\s\S]*)\g{1}\z", m))
            return rawArg
        prevStringCaseSense := A_StringCaseSense
        stringCaseSense % "On"
        try  {
            tp := m[2]
            out := ""
            spo := 1
            while (regExMatch(tp, "O)``(.)", m, spo))    {
                out .= subStr(tp, spo, m.pos(0) - spo)
                switch (m[1])
                {
                    case "n": out .= "`n"
                    case "r": out .= "`r"
                    case "b": out .= "`b"
                    case "t": out .= "`t"
                    case "v": out .= "`v"
                    case "a": out .= "`a"
                    case "f": out .= "`f"
                    default:  out .= m[1]
                }
                spo := m.pos(0) + m.len(0)
            }
            return out . subStr(tp, spo)
        }  finally  {
            stringCaseSense % prevStringCaseSense
        }
    }
    _deref(byRef str, scriptFullPath, ctx)    { ;  https://www.autohotkey.com/docs/v2/lib/RegExMatch.htm#ExDeref
        out := ""
        spo := 1
        while (regExMatch(str, "O)%(A_[A-Za-z]+)%", m, spo))    {
            switch (format(m[1], "{:L}")) ;  https://www.autohotkey.com/docs/v2/lib/_Include.htm#Parameters
            {
                case "a_linefile":          v := scriptFullPath
                case "a_scriptdir":         v := ctx.rootScriptDir
                case "a_scriptfullpath":    v := ctx.rootScriptPath
                case "a_scriptname":        v := ctx.rootScriptName
                default:                    tp := m[1], v := %tp%
            }
            out .= subStr(str, spo, m.pos(0) - spo) . v
            spo := m.pos(0) + m.len(0)
        }
        str := out . subStr(str, spo)
    }
    ;---------------------------------------------------------------------
    _readUtf8TextFile(scriptFullPath)    {
        prevFileEncoding := A_FileEncoding
        fileEncoding % "UTF-8"
        try {
            attr := fileExist(scriptFullPath)
            if (attr && !inStr(attr, "D"))    {
                fileRead text, % scriptFullPath
                return text
            }
            return ""
        } finally {
            fileEncoding % prevFileEncoding
        }
    }
    _commandLineToArgvW(cmdLine := "")    { ;  https://github.com/SevenKeyboard/command-line-to-argv-w/tree/main-ahkv1.1
        args := []
        if (pArgs:=dllCall("Shell32.dll\CommandLineToArgvW", "WStr",cmdLine, "Ptr*",nArgs, "Ptr"))    {
            loop % nArgs
                args.push(strGet(numGet((A_Index-1)*A_PtrSize+pArgs,"Ptr"),"UTF-16"))
            dllCall("Kernel32.dll\LocalFree", "Ptr",pArgs)
        }
        return args
    }
    _getFullPathName(fileName)    { ;  https://github.com/SevenKeyboard/get-full-path-name/tree/main-ahkv1.1
        neededChars := dllCall("Kernel32.dll\GetFullPathNameW", "WStr",fileName, "UInt",0, "Ptr",0, "Ptr",0, "UInt")
        if (!neededChars)
            return fileName
        varSetCapacity(fullPathName, neededChars * 2, 0)
        copiedChars := dllCall("Kernel32.dll\GetFullPathNameW", "WStr",fileName, "UInt",neededChars, "Ptr",&fullPathName, "Ptr",0, "UInt")
        if (!copiedChars)
            return fileName
        return strGet(&fullPathName, copiedChars, "UTF-16")
    }
    _isValidDomainDirName(name)    { ;  https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#naming-conventions
        if (name == "")
            return false
        if (name ~= "[\x00-\x1F<>:""/\\|?*]")
            return false
        if (name ~= "[ .]\z")
            return false
        if (name ~= "i)\A(?:AUX|CO(?:M[1-9\xB2\xB3\xB9]|N)|LPT[1-9\xB2\xB3\xB9]|NUL|PRN)(?:\.|\z)")
            return false
        return true
    }
    _encodeAllChars(str, encoding := "UTF-8") {
        varSetCapacity(buf, size := strPut(str, encoding) * ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1))
        strPut(str, &buf, encoding)
        out := ""
        loop % (size - 1)    {
            b := numGet(&buf, A_Index - 1, "UChar")
            out .= "%" format("{:02X}", b)
        }
        return out
    }
}
i18nMaskedLineRegexCallout_3EB975B3(match, calloutNumber, foundPos, haystack, needleRegEx)    {
    if (match[2] ~= "(?<![.0-9A-Z_a-z[:^ascii:]])"
        . "(?i)(_(?:_|nx?|x))"
        . "\(")
        return 1
    AhkV1_I18n.maskedLineMatches.push({match:match, calloutNumber:calloutNumber, foundPos:foundPos, haystack:haystack, needleRegEx:needleRegEx})
    return 1
}