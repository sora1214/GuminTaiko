; GuminTaiko のインストーラー（NSIS）。tools\make_installer.ps1 から呼ぶ
;   /DOUTFILE=出力する exe  /DVERSION=版  /DPAYLOAD=中身の zip の名前
; 中身（約 2.4GB）は NSIS の上限（2GB 前後）を超えるので、exe には入れず、同じフォルダに置いた zip を Windows の tar で展開する。
; インストール先はこのユーザーだけの場所（ゲームは同じフォルダに Backup・Songs・Data\cache を書くので、書き込める場所にする）。
; アンインストールでは、遊んだ記録（Backup）と足した曲（Songs・Data\x64\fumen・sound）は消さない。
Unicode true

!ifndef PAYLOAD
  !define PAYLOAD "GuminTaiko-Data.zip"
!endif
!ifndef OUTFILE
  !define OUTFILE "GuminTaiko-Setup.exe"
!endif
!ifndef VERSION
  !define VERSION "1.0"
!endif

!include "MUI2.nsh"

Name "GuminTaiko"
OutFile "${OUTFILE}"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\GuminTaiko"
InstallDirRegKey HKCU "Software\GuminTaiko" "InstallDir"
BrandingText "GuminTaiko ${VERSION}"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\GuminLauncher.exe"
!define MUI_FINISHPAGE_RUN_TEXT "ランチャーを起動する"
!define MUI_FINISHPAGE_NOREBOOTSUPPORT

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Japanese"

Section "GuminTaiko" SecMain
  SetOutPath "$INSTDIR"
  ; 前のインストールの読み取り専用を外してから上書きする
  nsExec::Exec 'attrib -R "$INSTDIR\*" /S /D'
!ifdef STAGE
  ; ウェブ版: ランチャーと、ランチャーの画面に要る最小限だけ入れる。残りは、ランチャーが初めて開いたとき、GitHub から取ってくる
  File /r "${STAGE}\*.*"
!else
  ; 中身の zip（インストーラーと同じフォルダ）を展開する
  IfFileExists "$EXEDIR\${PAYLOAD}" +3 0
    MessageBox MB_OK|MB_ICONSTOP "${PAYLOAD} が見つかりません。\n${PAYLOAD} を、このインストーラーと同じフォルダに置いてください。"
    Abort
  DetailPrint "ファイルを展開しています（数分かかります）…"
  nsExec::ExecToLog 'tar.exe -xf "$EXEDIR\${PAYLOAD}" -C "$INSTDIR"'
  Pop $0
  StrCmp $0 "0" +3 0
    MessageBox MB_OK|MB_ICONSTOP "展開に失敗しました（終了コード $0）。ディスクの空き容量（約 3GB）と、${PAYLOAD} が壊れていないかを確かめてください。"
    Abort
!endif
  ; 足す場所（曲・プレイヤーデータ・音の変換結果）。中身は自由に変えてよい
  CreateDirectory "$INSTDIR\Songs\創作譜面"
  CreateDirectory "$INSTDIR\Backup"
  CreateDirectory "$INSTDIR\Dani"
  CreateDirectory "$INSTDIR\Data\x64\fumen"
  CreateDirectory "$INSTDIR\Data\cache"

  WriteRegStr HKCU "Software\GuminTaiko" "InstallDir" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; ショートカット（ランチャー・着せかえ・段位道場のお題）
  CreateDirectory "$SMPROGRAMS\GuminTaiko"
  CreateShortCut "$SMPROGRAMS\GuminTaiko\GuminTaiko.lnk" "$INSTDIR\GuminLauncher.exe" "" "$INSTDIR\GuminTaiko.exe" 0
  CreateShortCut "$SMPROGRAMS\GuminTaiko\GuminTaiko 着せかえ.lnk" "$INSTDIR\GuminDressUp.exe"
  CreateShortCut "$SMPROGRAMS\GuminTaiko\GuminTaiko 段位道場のお題.lnk" "$INSTDIR\GuminDaniEditor.exe"
  CreateShortCut "$SMPROGRAMS\GuminTaiko\アンインストール.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortCut "$DESKTOP\GuminTaiko.lnk" "$INSTDIR\GuminLauncher.exe" "" "$INSTDIR\GuminTaiko.exe" 0

  ; 「アプリと機能」に出す
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GuminTaiko" "DisplayName" "GuminTaiko"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GuminTaiko" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GuminTaiko" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GuminTaiko" "DisplayIcon" "$INSTDIR\GuminTaiko.exe"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GuminTaiko" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GuminTaiko" "NoRepair" 1
SectionEnd

Section "Uninstall"
  nsExec::Exec 'attrib -R "$INSTDIR\*" /S /D'
  ; プログラムと素材だけを消す（Backup・Songs・Dani・Data\x64\fumen・曲の音源・Data\cache は残す）
  Delete "$INSTDIR\*.exe"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\manifest.sig"
  Delete "$INSTDIR\license.cert"
  RMDir /r "$INSTDIR\third_party"
  RMDir /r "$INSTDIR\Data\x64\lumen"
  RMDir /r "$INSTDIR\Data\x64\model"
  RMDir /r "$INSTDIR\Data\x64\movie"
  RMDir /r "$INSTDIR\Data\x64\textures"
  RMDir /r "$INSTDIR\Data\x64\font"
  RMDir /r "$INSTDIR\Data\x64\animation"
  RMDir /r "$INSTDIR\Data\x64\lua"
  RMDir /r "$INSTDIR\Data\x64\renderpipeline"
  RMDir /r "$INSTDIR\Data\x64\shader"
  RMDir /r "$INSTDIR\Data\x64\testmode"
  RMDir /r "$INSTDIR\Data\x64\datatable"
  Delete "$INSTDIR\Data\x64\sound\*.nus3bank"
  Delete "$INSTDIR\Data\x64\sound\*.nus3audio"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\GuminTaiko\*.lnk"
  RMDir "$SMPROGRAMS\GuminTaiko"
  Delete "$DESKTOP\GuminTaiko.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GuminTaiko"
  DeleteRegKey HKCU "Software\GuminTaiko"
SectionEnd
