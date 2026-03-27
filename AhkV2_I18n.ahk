;@I18n-IgnoreFile
#Requires AutoHotkey v2.0.0+
;==============================================================
; AhkV2_I18n — A toolkit for gettext-style internationalization workflows
;
; GitHub: https://github.com/SevenKeyboard/i18n
; Author: SevenKeyboard Ltd. (2026)
; License: MIT License
;
; Documentation / References:
;   AhkV2_publishCompiledTranslationsToRuntimeLocale.ahk
;     https://github.com/SevenKeyboard/publish-compiled-translations-to-runtime-locale/blob/main/AhkV2_publishCompiledTranslationsToRuntimeLocale.ahk
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

    ;  #Include <AhkV2_I18n>
    ;  AhkV2_I18n.makePot()
*/

/*
%A_MyDocuments%\
└─ AutoHotkey\
   └─ lib\
      └─ AhkV2_I18n.ahk
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

class VersionManager_AhkV2_I18n
{
    static _ := this._init()
    static _init()    {
        global
        AHKV2_I18N_VERSION := AhkV2_I18n.Version
    }
}
class AhkV2_I18n
{
    static Version => "0.0.0"
    static makePot(cmdLine := "")    { ;  https://developer.wordpress.org/cli/commands/i18n/make-pot/
        args := cmdLine !== "" ? this._commandLineToArgvW(cmdLine) : []
        positionals := []
        options := map("location",true), parsingOptions := true
        for arg in args    {
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
            if (2 <= positionals.Length)
                throw valueError("Parameter #1 of AhkV2_I18n.makePot must not contain more than 2 positional arguments.", -1)
            positionals.push(arg)
        }
        ;----------------------------------
        rootScriptPath  := positionals.has(1) ? this._getFullPathName(positionals[1]) : A_ScriptFullPath
        splitPath(rootScriptPath, &rootScriptName, &rootScriptDir)
        ctx := {rootScriptPath:rootScriptPath
            ,rootScriptName:rootScriptName
            ,rootScriptDir:rootScriptDir}
        state := {visitedPaths:Map()
            ,messagesByKey:Map()}
        state.visitedPaths.CaseSense    := false
        state.messagesByKey.CaseSense   := true
        prevIsCritical := critical("On")
        try  {
            this._scanScriptFile(rootScriptPath, ctx, state)
        }  finally  {
            critical(prevIsCritical)
        }
        /*
        for msgKey,message in state.messagesByKey    {
            outputDebug "callType: " . message.callType
            outputDebug "reference: "
            for j,reference in message.references
                outputDebug "    " . reference.file . "#L" . reference.line
            for name,prop in message.ownProps()    {
                if (name == "callType" || name == "references" || name == "_referenceKeys")
                    continue
                outputDebug name . " :" . prop
            }
            outputDebug "----------------------------------"
        }
        */
        ;----------------------------------
        languagesDir := positionals.has(2) ? this._getFullPathName(positionals[2]) : rootScriptDir . "\languages"
        messagesByDomain := this._buildMessagesByDomain(state)
        for domainName,messages in messagesByDomain    {
            domainDir   := languagesDir . "\" . domainName
            potFilePath := domainDir . "\messages.pot"
            dirCreate(domainDir)
            try fileDelete(potFilePath)
            fileAppend(this._buildPot(messages, options), potFilePath, "UTF-8-RAW")
        }
    }
    ;---------------------------------------------------------------------
    static _buildMessagesByDomain(state)    {
        messagesByDomain := Map()
        messagesByDomain.CaseSense := false
        for _,message in state.messagesByKey    {
            domainName := message.domain
            if (!messagesByDomain.has(domainName))
                messagesByDomain[domainName] := []
            messagesByDomain[domainName].push(message)
        }
        return messagesByDomain
    }
    static _buildPot(messages, options?)    {
        pot := this._buildPotHeader(options)
        for message in messages
            pot .= "`r`n`r`n" . this._buildPotEntry(message, options)
        return pot
    }
    static _buildPotHeader(options?)    {
        return format("
(Join`r`n LTrim0  RTrim0
msgid `"`"
msgstr `"`"
`"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n`"
`"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n`"
`"Language-Team: LANGUAGE <LL@li.org>\n`"
`"X-Generator: AhkV2_I18n {1}\n`"
)", this.Version)
    }
    static _buildPotEntry(message, options?)    {
        entry := ""
        if (isSet(options) && options.has("location") && options["location"])    {
            for reference in message.references
                entry .= "#: " . reference.file . ":" . reference.line . "`r`n"
        }
        if (message.hasOwnProp("msgctxt"))
            entry .= "msgctxt " . this._escapePotString(message.msgctxt) . "`r`n"
        entry .= "msgid " . this._escapePotString(message.msgid) . "`r`n"
        if (message.hasOwnProp("msgidPlural"))    {
            entry .= "msgid_plural " . this._escapePotString(message.msgidPlural) . "`r`n"
            entry .= "msgstr[0] `"`"`r`n"
            entry .= "msgstr[1] `"`""
        }  else  {
            entry .= "msgstr `"`""
        }
        return entry
    }
    static _escapePotString(str)    {
        str := strReplace(str, '`r`n', '`n')
        str := strReplace(str, '`r', '`n')
        str := strReplace(str, '\', '\\')
        str := strReplace(str, '"', '\"')
        return inStr(str, '`n')
            ? ('""`r`n"' . strReplace(str, '`n', '\n"`r`n"') . '"')
            : ('"' . str . '"')
    }
    ;---------------------------------------------------------------------
    static _scanScriptFile(scriptFullPath, ctx, state)    {
        if (state.visitedPaths.has(scriptFullPath))
            return
        state.visitedPaths[scriptFullPath] := true
        ;----------------------------------
        fileText := this._readUtf8TextFile(scriptFullPath)
        if (this._shouldIgnoreFile(&fileText))
            return
        ;----------------------------------
        result := this._collectIncludeSpecsAndMessages(&fileText, scriptFullPath, ctx, state)
        ;----------------------------------
        includePaths := this._resolveIncludeSpecs(result.includeSpecs, scriptFullPath, ctx)
        for path in includePaths
            this._scanScriptFile(path, ctx, state)
    }
    static _shouldIgnoreFile(&fileText)    {
        loop parse, fileText, "`n", "`r"
        {
            trimmedLine := trim(A_LoopField)
            if (trimmedLine == "")    {
                continue
            }  else if (subStr(trimmedLine, 1, 1) == "#")    {
                continue
            }  else if (regExMatch(trimmedLine, "i)\A;@I18n-(.*)", &m))    {
                if (m[1] = "IgnoreFile")
                    return true
                continue
            }
            break
        }
        return false
    }
    static _collectIncludeSpecsAndMessages(&fileText, scriptFullPath, ctx, state)    {
        inBlockComment  := false
        ignoreBlock     := false
        skipNextLine    := false
        inLiteral               := false
        inContinuationLiteral   := false
        stringQuoteChar         := ""
        skipNextChar            := false
        includeSpecs := []
        loop parse, fileText, "`n", "`r"
        {
            ;----------------------------------
            lineNumber := A_Index
            trimmedLine := trim(A_LoopField)
            skipThisLine := skipNextLine, skipNextLine := false
            isBlockCommentStart := (trimmedLine ~= "\A/\*")
            isBlockCommentEnd   := (trimmedLine ~= "\*/\z")
            if (isBlockCommentStart)    {
                inBlockComment := !isBlockCommentEnd
                continue
            }
            if (inBlockComment)    {
                if (isBlockCommentEnd)
                    inBlockComment := false
                continue
            }
            if (regExMatch(trimmedLine, "i)\A;@I18n-(.*)", &m))    {
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
            loop parse, currLine
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
                        inLiteral := false
                        stringQuoteChar := ""
                        maskedLine .= currChar
                        continue
                    }
                    maskedLine .= A_Space
                    continue
                }
                if (currChar == '"' || currChar == "'")    {
                    inLiteral := true
                    stringQuoteChar := currChar
                    maskedLine .= currChar
                    continue
                }
                if (currChar == ";")    {
                    if (prevChar == "" || prevChar == A_Space || prevChar == A_Tab)
                        break
                }
                if (currChar == "#")    {
                    if (regExMatch(currLine, "i)\A[ `t]*#Include(?:Again)?[ `t]+\K.+", &m))    {
                        spec := regExMatch(m[0], "\A([`"'])([^`"']+)\g{1}", &s)
                            ? s[2]
                            : rTrim(regExReplace(m[0], "(?<=[ `t]);.*"))
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
            regExMatch(maskedLine, "(?<![.0-9A-Z_a-z[:^ascii:]])"
                . "(?i)(_(?:_|nx?|x))"
                . "\((.+?)\)(?Ci18nMaskedLineRegexCallout_3EB975B3)")
            for i,v in this.maskedLineMatches    {
                rawMaskedArgs := []
                nestingCloser := ""
                nestingOpener := ""
                nestingDepth := 0
                w2 := ""
                for w1 in strSplit(v.match[2], ",")    {
                    w2 .= (w2 !== "" ? "," : "") . w1
                    if (nestingDepth == 0)    {
                        if (regExMatch(w1, "[(\[{]", &m))    {
                            nestingOpener := m[0]
                            nestingCloser := (m[0] == "(" ? ")" : m[0] == "[" ? "]" : "}")
                            regExReplace(w1, "\Q" . nestingOpener . "\E",, &openCount)
                            regExReplace(w1, "\Q" . nestingCloser . "\E",, &closeCount)
                            nestingDepth := openCount - closeCount
                        }
                    }  else  {
                        regExReplace(w1, "\Q" . nestingOpener . "\E",, &openCount)
                        regExReplace(w1, "\Q" . nestingCloser . "\E",, &closeCount)
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
                callType := strLower(v.match[1])
                switch callType, true
                {
                    case "__":      requiredParamCount := 1
                    case "_n":      requiredParamCount := 3
                    case "_x":      requiredParamCount := 2
                    case "_nx":     requiredParamCount := 4
                    default:        continue
                }
                if (rawMaskedArgs.Length < requiredParamCount || requiredParamCount + 1 < rawMaskedArgs.Length)
                    continue
                for j,rawMaskedArg in rawMaskedArgs    {
                    if (j == 3 && (callType == "_n" || callType == "_nx")) ;  num
                        continue
                    if !(rawMaskedArg ~= "\A[ \t]*([`"']) *\g{1}[ \t]*\z")
                        continue 2
                }
                ;----------------------------------
                rawArgs := []
                rawArgSlice := subStr(currLine
                        ,v.foundPos + (temp := strLen(callType)) + 1
                        ,v.match.Len[0] - temp - 2)
                pos := 1
                len := 0
                for rawMaskedArg in rawMaskedArgs    {
                    len := strLen(rawMaskedArg)
                    rawArgs.push(trim(subStr(rawArgSlice, pos, len)))
                    pos += len + 1
                }
                args := []
                domainName := ""
                for j,rawArg in rawArgs    {
                    args.push(temp := this._parseIfAhkStringLiteral(rawArg))
                    if (j == requiredParamCount + 1)    {
                        domainName := strLower(temp)
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
                if (!state.messagesByKey.has(msgKey))    {
                    state.messagesByKey[msgKey] := {callType:callType, references:[], _referenceKeys:Map()}
                    state.messagesByKey[msgKey]._referenceKeys.CaseSense := false
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
                if (!state.messagesByKey[msgKey]._referenceKeys.has(refKey))    {
                    state.messagesByKey[msgKey]._referenceKeys[refKey] := true
                    state.messagesByKey[msgKey].references.push({file:scriptFullPath, line:lineNumber})
                }
            }
        }
        return {includeSpecs:includeSpecs}
    }
    static _resolveIncludeSpecs(includeSpecs, scriptFullPath, ctx)    {
        includePaths := []
        prevWorkingDir := A_WorkingDir
        try  {
            splitPath(scriptFullPath,, &includeBaseDir)
            setWorkingDir(includeBaseDir)
            for spec in includeSpecs
            {
                path := ""
                if (regExMatch(spec, "\A([`"']?)<(.+)>\g{1}\z", &m))    {
                    libName := m[2]
                    path := this._resolveLibIncludeSpec(libName, ctx)
                }  else  {
                    this._deref(&spec, scriptFullPath, ctx)
                    path := this._getFullPathName(spec)
                    if (inStr(fileExist(path), "D"))    {
                        setWorkingDir(path)
                        continue
                    }
                }
                if (path !== "")
                    includePaths.push(path)
            }
        }  finally  {
            setWorkingDir(prevWorkingDir)
        }
        return includePaths
    }
    static _resolveLibIncludeSpec(libName, ctx)    {
        splitPath(A_AhkPath,, &ahkDir)
        searchDirs := [ctx.rootScriptDir . "\Lib"
            ,A_MyDocuments . "\AutoHotkey\Lib"
            ,ahkDir . "\Lib"]
        fallbackLibName := regExMatch(libName, "\A([^_]+)_", &m) ? m[1] : ""
        for dir in searchDirs    {
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
    static _parseIfAhkStringLiteral(rawArg)    {
        if (!regExMatch(rawArg, "\A([`"'])([\s\S]*)\g{1}\z", &m))
            return rawArg
        temp := m[2]
        out := ""
        spo := 1
        while (regExMatch(temp, "``(.)", &m, spo))    {
            out .= subStr(temp, spo, m.Pos[0] - spo)
            switch (m[1])
            {
                case "n": out .= "`n"
                case "r": out .= "`r"
                case "b": out .= "`b"
                case "t": out .= "`t"
                case "s": out .= "`s"
                case "v": out .= "`v"
                case "a": out .= "`a"
                case "f": out .= "`f"
                default:  out .= m[1]
            }
            spo := m.Pos[0] + m.Len[0]
        }
        return out . subStr(temp, spo)
    }
    static _deref(&str, scriptFullPath, ctx)    { ;  https://www.autohotkey.com/docs/v2/lib/RegExMatch.htm#ExDeref
        out := ""
        spo := 1
        while (regExMatch(str, "%(A_[A-Za-z]+)%", &m, spo))    {
            switch (strLower(m[1])) ;  https://www.autohotkey.com/docs/v2/lib/_Include.htm#Parameters
            {
                case "a_linefile":          v := scriptFullPath
                case "a_scriptdir":         v := ctx.rootScriptDir
                case "a_scriptfullpath":    v := ctx.rootScriptPath
                case "a_scriptname":        v := ctx.rootScriptName
                default:                    v := %m[1]%
            }
            out .= subStr(str, spo, m.Pos[0] - spo) . v
            spo := m.Pos[0] + m.Len[0]
        }
        str := out . subStr(str, spo)
    }
    ;---------------------------------------------------------------------
    static _readUtf8TextFile(scriptFullPath)    {
        prevFileEncoding := A_FileEncoding
        A_FileEncoding := "UTF-8"
        try {
            return fileRead(scriptFullPath)
        } finally {
            A_FileEncoding := prevFileEncoding
        }
    }
    static _commandLineToArgvW(cmdLine := "")    { ;  https://github.com/SevenKeyboard/command-line-to-argv-w
        args := []
        if (pArgs:=dllCall("Shell32.dll\CommandLineToArgvW", "WStr",cmdLine, "Ptr*",&nArgs:=0, "Ptr"))    {
            loop nArgs
                args.push(strGet(numGet((A_Index-1)*A_PtrSize+pArgs,"Ptr"),"UTF-16"))
            dllCall("Kernel32.dll\LocalFree", "Ptr",pArgs)
        }
        return args
    }
    static _getFullPathName(fileName)    {
        neededChars := dllCall("Kernel32.dll\GetFullPathNameW", "WStr",fileName, "UInt",0, "Ptr",0, "Ptr",0, "UInt")
        if (!neededChars)
            return fileName
        fullPathName := buffer(neededChars * 2, 0)
        copiedChars := dllCall("Kernel32.dll\GetFullPathNameW", "WStr",fileName, "UInt",neededChars, "Ptr",fullPathName.Ptr, "Ptr",0, "UInt")
        if (!copiedChars)
            return fileName
        return strGet(fullPathName, copiedChars, "UTF-16")
    }
    static _isValidDomainDirName(name)    { ;  https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#naming-conventions
        if (name == "")
            return false
        if (name ~= '[\x00-\x1F<>:"/\\|?*]')
            return false
        if (name ~= '[ .]\z')
            return false
        if (name ~= "i)\A(?:AUX|CO(?:M[1-9\xB2\xB3\xB9]|N)|LPT[1-9\xB2\xB3\xB9]|NUL|PRN)(?:\.|\z)")
            return false
        return true
    }
}
i18nMaskedLineRegexCallout_3EB975B3(match, calloutNumber, foundPos, haystack, needleRegEx)    {
    if (match[2] ~= "(?<![.0-9A-Z_a-z[:^ascii:]])"
        . "(?i)(_(?:_|nx?|x))"
        . "\(")
        return 1
    AhkV2_I18n.maskedLineMatches.push({match:match, calloutNumber:calloutNumber, foundPos:foundPos, haystack:haystack, needleRegEx:needleRegEx})
    return 1
}