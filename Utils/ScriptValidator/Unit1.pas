unit Unit1;

interface
uses
  Windows, Messages, Classes, Controls, Dialogs, Forms, StdCtrls, StrUtils, SysUtils, FileCtrl,
  KM_Defaults, KM_Scripting, shellapi;

type
  TKMFileOrFolder = (fof_None, fof_File, fof_Folder);

  TForm1 = class(TForm)
    Edit1: TEdit;
    btnBrowseFile: TButton;
    Label1: TLabel;
    btnValidate: TButton;
    OpenDialog: TOpenDialog;
    Memo1: TMemo;
    Label2: TLabel;
    btnValidateAll: TButton;
    btnBrowsePath: TButton;
    FileOpenDlg: TFileOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure btnBrowseFileClick(Sender: TObject);
    procedure btnValidateClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnValidateAllClick(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure btnBrowsePathClick(Sender: TObject);
  private
    fScripting: TKMScripting;
    fIsValidatePath : TKMFileOrFolder;
    fListFileInFolder : TStringList;

    procedure FindFiles(aPath: String; out aList: TStringList);
    procedure Validate(aPath: string; aReportGood: Boolean);
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
    procedure EnableFormComponents(aEnabled : Boolean);
  end;

var
  Form1: TForm1;
implementation
uses
  KM_Maps, KM_CommonUtils;

{$R *.dfm}

procedure TForm1.FindFiles(aPath: String; out aList: TStringList);
var
  SearchRec:TSearchRec;
begin
  FindFirst(aPath + PathDelim + '*', faAnyFile, SearchRec);
  repeat
    if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      if (SearchRec.Attr and faDirectory = faDirectory) then
        FindFiles(aPath + PathDelim + SearchRec.Name, aList)
      else
        if SameText(ExtractFileExt(SearchRec.Name), '.' + EXT_FILE_SCRIPT) then
          aList.Add(aPath + PathDelim + SearchRec.Name);
  until (FindNext(SearchRec) <> 0);
  FindClose(SearchRec);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  KmrDir: String;
begin
  KmrDir := ExtractFilePath(ParamStr(0));

  Caption                   := 'KaM Remake Script Validator (' + GAME_REVISION + ')';
  OpenDialog.InitialDir     := KmrDir;
  FileOpenDlg.DefaultFolder := KmrDir;
  fScripting                := TKMScriptingCreator.CreateScripting(nil);
  fListFileInFolder         := TStringList.Create;
  DragAcceptFiles(Handle, True);
  Edit1Change(nil);
end;


procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(fScripting);
  fListFileInFolder.Free;
  DragAcceptFiles(Handle, False);
end;


procedure TForm1.btnBrowseFileClick(Sender: TObject);
begin
  if not OpenDialog.Execute then Exit;
  Edit1.Text := OpenDialog.FileName;
end;


procedure TForm1.btnBrowsePathClick(Sender: TObject);
var
  DirToValidate : String;
begin
  if Win32MajorVersion >= 6 then // For Vista+ Windows version we can use FileOpenDlg
  begin
    FileOpenDlg.FileName := '';
    if FileOpenDlg.Execute then
    begin
      FileOpenDlg.DefaultFolder := FileOpenDlg.FileName;
      Edit1.Text := FileOpenDlg.FileName;
    end;
  end else begin // Fine for XP+
    if SelectDirectory('Select folder to Validate scripts', '', DirToValidate) then
      Edit1.Text := DirToValidate;
  end;
end;


procedure TForm1.Edit1Change(Sender: TObject);
begin
  fIsValidatePath := fof_None;

  if FileExists(Edit1.Text) and (ExtractFileExt(Edit1.Text) = '.' + EXT_FILE_SCRIPT) then
    fIsValidatePath := fof_File
  else
    if SysUtils.DirectoryExists(Edit1.Text) then
      fIsValidatePath := fof_Folder;

  case fIsValidatePath of
    fof_None:   begin
                  if Sender <> nil then
                    Memo1.Text := 'Wrong script file/folder path selected'
                  else
                    Memo1.Text := 'Select file or folder to validate';
                  btnValidate.Enabled := False;
                  btnValidate.Caption := 'Validate';
                end;
    fof_File:   begin
                  Memo1.Text := 'File selected';
                  btnValidate.Enabled := True;
                  btnValidate.Caption := 'Validate file';
                end;
    fof_Folder: begin
                  Memo1.Text := 'Folder selected';
                  btnValidate.Enabled := True;
                  btnValidate.Caption := 'Validate folder';
                end;
  end;
end;


procedure TForm1.EnableFormComponents(aEnabled: Boolean);
begin
  btnBrowsePath.Enabled := aEnabled;
  btnBrowseFile.Enabled := aEnabled;
  btnValidate.Enabled := aEnabled;
  btnValidateAll.Enabled := aEnabled;
  Edit1.Enabled := aEnabled;
end;


procedure TForm1.btnValidateClick(Sender: TObject);
var
  I : Integer;
begin
  EnableFormComponents(False);

  Memo1.Lines.Clear;
  if fIsValidatePath = fof_Folder then
  begin
    ExcludeTrailingPathDelimiter(Edit1.Text);
    if not SysUtils.DirectoryExists(Edit1.Text) then
      Memo1.Lines.Append('Directory not found ' + Edit1.Text)
    else
    begin
      Memo1.Lines.Append('Search for files in a folder ...');
      fListFileInFolder.Clear;
      Memo1.Lines.Append('Check ' + Edit1.Text);
      FindFiles(Edit1.Text, fListFileInFolder);
      if fListFileInFolder.Count = 0 then
        Memo1.Lines.Append('No files in a directory ' + Edit1.Text)
      else
      begin
        Memo1.Lines.Append('Files in folder: ' + IntToStr(fListFileInFolder.Count));
        for I := 0 to fListFileInFolder.Count - 1 do
          Validate(fListFileInFolder.Strings[I], True);
        Memo1.Lines.Append('Checked ' + IntToStr(fListFileInFolder.Count));
      end;
    end;
  end else if fIsValidatePath = fof_File then
    Validate(Edit1.Text, True);

  EnableFormComponents(True);
end;


procedure TForm1.btnValidateAllClick(Sender: TObject);
var
  I: Integer;
begin
  EnableFormComponents(False);

  Memo1.Lines.Clear;

  Memo1.Lines.Append('Check ' + ExtractFilePath(ParamStr(0)));
  // Exe path
  TKMapsCollection.GetAllMapPaths(ExtractFilePath(ParamStr(0)), fListFileInFolder);
  if fListFileInFolder.Count = 0 then
    Memo1.Lines.Append('No files in a directory :(')
  else
  begin
    Memo1.Lines.Append('Files in the folder: '+IntToStr(fListFileInFolder.Count));
    for I := 0 to fListFileInFolder.Count - 1 do
      Validate(ChangeFileExt(fListFileInFolder[I], '.' + EXT_FILE_SCRIPT), False);

    Memo1.Lines.Append('Checked ' + IntToStr(fListFileInFolder.Count) + ' in .\');
  end;
  // Utils path
  Memo1.Lines.Append('Check ' + ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\'));
  TKMapsCollection.GetAllMapPaths(ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\'), fListFileInFolder);
  if fListFileInFolder.Count = 0 then
    Memo1.Lines.Append('No files in a directory :(')
  else
  begin
    Memo1.Lines.Append('Files in the folder: '+IntToStr(fListFileInFolder.Count));
    for I := 0 to fListFileInFolder.Count - 1 do
      Validate(ChangeFileExt(fListFileInFolder[I], '.' + EXT_FILE_SCRIPT), False);

    Memo1.Lines.Append('Checked ' + IntToStr(fListFileInFolder.Count));
  end;
  EnableFormComponents(True);
end;

procedure TForm1.Validate(aPath: string; aReportGood: Boolean);
var
  CampaignFile: UnicodeString;
  txt:          string;
begin
  if not FileExists(aPath) and aReportGood then
  begin
    Memo1.Lines.Append('File not found ' + aPath);
    Exit;
  end;

  fScripting.ErrorHandler.Clear;

  CampaignFile := ExtractFilePath(aPath) + '..\campaigndata.' + EXT_FILE_SCRIPT;
  fScripting.LoadFromFile(aPath, CampaignFile, nil);

  txt := StringReplace(fScripting.ErrorHandler.ErrorString.GameMessage, '|', sLineBreak, [rfReplaceAll]);

  if fScripting.ErrorHandler.HasWarnings then
  begin
    if txt <> '' then
      txt := txt + sLineBreak;
    txt := txt + 'Warnings:' + sLineBreak;
    txt := txt + StringReplace(fScripting.ErrorHandler.WarningsString.GameMessage, '|', sLineBreak, [rfReplaceAll]);
  end;

  if txt <> '' then
    Memo1.Lines.Append(aPath + sLineBreak + txt)
  else
    if aReportGood then
      Memo1.Lines.Append(aPath + ' - No errors :)');
end;


procedure TForm1.WMDropFiles(var Msg: TWMDropFiles);
var
  Filename: array[0 .. MAX_PATH] of Char;
begin
  DragQueryFile(Msg.Drop, 0, Filename, MAX_PATH);
  Edit1.Text := Filename;
  DragFinish(Msg.Drop);
end;

end.
