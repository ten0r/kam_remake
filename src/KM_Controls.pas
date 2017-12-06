﻿unit KM_Controls;
{$I KaM_Remake.inc}
interface
uses
  Classes, Controls,
  KromOGLUtils,
  KM_RenderUI, KM_Pics, KM_Minimap, KM_Viewport, KM_ResFonts,
  KM_CommonClasses, KM_CommonTypes, KM_Points, KM_Defaults;


type
  TNotifyEventShift = procedure(Sender: TObject; Shift: TShiftState) of object;
  TNotifyEventMB = procedure(Sender: TObject; AButton: TMouseButton) of object;
  TNotifyEventMW = procedure(Sender: TObject; WheelDelta: Integer) of object;
  TNotifyEventKey = procedure(Sender: TObject; Key: Word) of object;
  TNotifyEventKeyFunc = function(Sender: TObject; Key: Word): Boolean of object;
  TNotifyEventKeyShift = procedure(Key: Word; Shift: TShiftState) of object;
  TNotifyEventKeyShiftFunc = function(Sender: TObject; Key: Word; Shift: TShiftState): Boolean of object;
  TNotifyEventXY = procedure(Sender: TObject; X, Y: Integer) of object;
  TNotifyEvenClickHold = procedure(Sender: TObject; AButton: TMouseButton; var aHandled: Boolean) of object;

  TKMControlState = (csDown, csFocus, csOver);
  TKMControlStateSet = set of TKMControlState;

  TKMControl = class;
  TKMPanel = class;

  { TKMMaster }
  TKMMasterControl = class
  private
    fMasterPanel: TKMPanel; //Parentmost control (TKMPanel with all its childs)
    fCtrlDown: TKMControl; //Control that was pressed Down
    fCtrlFocus: TKMControl; //Control which has input Focus
    fCtrlOver: TKMControl; //Control which has cursor Over it
    fCtrlUp: TKMControl; //Control above which cursor was released

    fControlIDCounter: Integer;

    fOnHint: TNotifyEvent; //Comes along with OnMouseOver

    function IsCtrlCovered(aCtrl: TKMControl): Boolean;
    procedure SetCtrlDown(aCtrl: TKMControl);
    procedure SetCtrlFocus(aCtrl: TKMControl);
    procedure SetCtrlOver(aCtrl: TKMControl);
    procedure SetCtrlUp(aCtrl: TKMControl);
    
    function GetNextCtrlID: Integer;
  public
    destructor Destroy; override;

    property MasterPanel: TKMPanel read fMasterPanel;
    function IsFocusAllowed(aCtrl: TKMControl): Boolean;
    function IsAutoFocusAllowed(aCtrl: TKMControl): Boolean;
    procedure UpdateFocus(aSender: TKMControl);

    property CtrlDown: TKMControl read fCtrlDown write SetCtrlDown;
    property CtrlFocus: TKMControl read fCtrlFocus write SetCtrlFocus;
    property CtrlOver: TKMControl read fCtrlOver write SetCtrlOver;
    property CtrlUp: TKMControl read fCtrlUp write SetCtrlUp;

    property OnHint: TNotifyEvent write fOnHint;

    function HitControl(X,Y: Integer; aIncludeDisabled: Boolean=false): TKMControl;

    function KeyDown    (Key: Word; Shift: TShiftState): Boolean;
    procedure KeyPress  (Key: Char);
    function KeyUp      (Key: Word; Shift: TShiftState): Boolean;
    procedure MouseDown (X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
    procedure MouseMove (X,Y: Integer; Shift: TShiftState);
    procedure MouseUp   (X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
    procedure MouseWheel(X,Y: Integer; WheelDelta: Integer);

    procedure Paint;

    procedure SaveToFile(const aFileName: UnicodeString);

    procedure UpdateState(aTickCount: Cardinal);
  end;


  {Base class for all TKM elements}
  TKMControl = class
  private
    fParent: TKMPanel;
    fAnchors: TKMAnchorsSet;

    //Left and Top are floating-point to allow to precisely store controls position
    //when Anchors [] are used. Cos that means that control must be centered
    //even if the Parent resized by 1px. Otherwise error quickly accumulates on
    //multiple 1px resizes
    //Everywhere else Top and Left are accessed through Get/Set and treated as Integers
    fLeft: Single;
    fTop: Single;
    fWidth: Integer;
    fHeight: Integer;

    fEnabled: Boolean;
    fVisible: Boolean;
    fControlIndex: Integer; //Index number of this control in his Parent's (TKMPanel) collection
    fID: Integer; //Control global ID

    fTimeOfLastClick: Cardinal; //Required to handle double-clicks

    fClickHoldMode: Boolean;
    fClickHoldHandled: Boolean;
    fTimeOfLastMouseDown: Cardinal;
    fLastMouseDownButton: TMouseButton;

    fOnClick: TNotifyEvent;
    fOnClickShift: TNotifyEventShift;
    fOnClickRight: TPointEvent;
    fOnClickHold: TNotifyEvenClickHold;
    fOnDoubleClick: TNotifyEvent;
    fOnMouseWheel: TNotifyEventMW;
    fOnFocus: TBooleanEvent;
    fOnChangeVisibility: TBooleanEvent;
    fOnChangeEnableStatus: TBooleanEvent;
    fOnKeyDown: TNotifyEventKeyShiftFunc;
    fOnKeyUp: TNotifyEventKeyShiftFunc;

    function GetAbsLeft: Integer;
    function GetAbsTop: Integer;
    function GetAbsRight: Integer;
    function GetAbsBottom: Integer;
    function GetLeft: Integer;
    function GetTop: Integer;
    function GetRight: Integer;
    function GetBottom: Integer;
    function GetHeight: Integer;
    function GetWidth: Integer;
    function GetCenter: TKMPoint;

    //Let the control know that it was clicked to do its internal magic
    procedure DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); virtual;

    function GetVisible: Boolean;
    procedure SetAbsLeft(aValue: Integer);
    procedure SetAbsTop(aValue: Integer);
    procedure SetTopF(aValue: Single);
    procedure SetLeftF(aValue: Single);
    function GetControlRect: TKMRect;
    function GetIsFocused: Boolean;
    function GetIsClickable: Boolean;

    procedure ResetClickHoldMode;
  protected
    procedure SetLeft(aValue: Integer); virtual;
    procedure SetTop(aValue: Integer); virtual;
    procedure SetHeight(aValue: Integer); virtual;
    procedure SetWidth(aValue: Integer); virtual;
    procedure SetVisible(aValue: Boolean); virtual;
    procedure SetEnabled(aValue: Boolean); virtual;
    procedure SetAnchors(aValue: TKMAnchorsSet); virtual;
    function GetSelfAbsLeft: Integer; virtual;
    function GetSelfAbsTop: Integer; virtual;
    function GetSelfHeight: Integer; virtual;
    function GetSelfWidth: Integer; virtual;
    procedure UpdateVisibility; virtual;
    procedure UpdateEnableStatus; virtual;
    procedure ControlMouseDown(Sender: TObject; Shift: TShiftState); virtual;
    procedure ControlMouseUp(Sender: TObject; Shift: TShiftState); virtual;
    procedure FocusChanged(aFocused: Boolean); virtual;
    procedure DoClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean); virtual;
  public
    Hitable: Boolean; //Can this control be hit with the cursor?
    Focusable: Boolean; //Can this control have focus (e.g. TKMEdit sets this true)
    AutoFocusable: Boolean; //Can we focus on this element automatically (f.e. if set to False we will able to Focus only by manual mouse click)

    State: TKMControlStateSet; //Each control has it localy to avoid quering Collection on each Render
    Scale: Single; //Child controls position is scaled

    Tag: Integer; //Some tag which can be used for various needs
    Hint: UnicodeString; //Text that shows up when cursor is over that control, mainly for Buttons
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    function HitTest(X, Y: Integer; aIncludeDisabled: Boolean=false): Boolean; virtual;

    property Parent: TKMPanel read fParent;
    property AbsLeft: Integer read GetAbsLeft write SetAbsLeft;
    property AbsRight: Integer read GetAbsRight;
    property AbsTop: Integer read GetAbsTop write SetAbsTop;
    property AbsBottom: Integer read GetAbsBottom;
    property Left: Integer read GetLeft write SetLeft;
    property Right: Integer read GetRight;
    property Top: Integer read GetTop write SetTop;
    property Bottom: Integer read GetBottom;
    property Width: Integer read GetWidth write SetWidth;
    property Height: Integer read GetHeight write SetHeight;
    property Center: TKMPoint read GetCenter;
    property ID: Integer read fID;

    // "Self" coordinates - this is the coordinates of control itself.
    // For simple controls they are equal to normal coordinates
    // but for composite controls this is coord. for control itself, without any other controls inside composite
    // (f.e. for TKMNumericEdit this is his internal edit coord without Inc/Dec buttons)
    property SelfAbsLeft: Integer read GetSelfAbsLeft;
    property SelfAbsTop: Integer read GetSelfAbsTop;
    property SelfWidth: Integer read GetSelfWidth;
    property SelfHeight: Integer read GetSelfHeight;

    property Rect: TKMRect read GetControlRect;
    property Anchors: TKMAnchorsSet read fAnchors write SetAnchors;
    property Enabled: Boolean read fEnabled write SetEnabled;
    property Visible: Boolean read GetVisible write SetVisible;
    property IsFocused: Boolean read GetIsFocused;
    property IsClickable: Boolean read GetIsClickable;  // Control considered 'Clickabale' if it is Visible and Enabled
    property ControlIndex: Integer read fControlIndex;
    procedure Enable;
    procedure Disable;
    procedure Show;
    procedure Hide;
    procedure Focus;
    procedure Unfocus;
    procedure AnchorsCenter;
    procedure AnchorsStretch;
    function MasterParent: TKMPanel;

    function KeyDown(Key: Word; Shift: TShiftState): Boolean; virtual;
    procedure KeyPress(Key: Char); virtual;
    function KeyUp(Key: Word; Shift: TShiftState): Boolean; virtual;
    procedure MouseDown (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); virtual;
    procedure MouseMove (X,Y: Integer; Shift: TShiftState); virtual;
    procedure MouseUp   (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); virtual;
    procedure MouseWheel(Sender: TObject; WheelDelta: Integer); virtual;

    property OnClick: TNotifyEvent read fOnClick write fOnClick;
    property OnClickShift: TNotifyEventShift read fOnClickShift write fOnClickShift;
    property OnClickRight: TPointEvent read fOnClickRight write fOnClickRight;
    property OnClickHold: TNotifyEvenClickHold read fOnClickHold write fOnClickHold;
    property OnDoubleClick: TNotifyEvent read fOnDoubleClick write fOnDoubleClick;
    property OnMouseWheel: TNotifyEventMW read fOnMouseWheel write fOnMouseWheel;
    property OnFocus: TBooleanEvent read fOnFocus write fOnFocus;
    property OnChangeVisibility: TBooleanEvent read fOnChangeVisibility write fOnChangeVisibility;
    property OnChangeEnableStatus: TBooleanEvent read fOnChangeEnableStatus write fOnChangeEnableStatus;
    property OnKeyDown: TNotifyEventKeyShiftFunc read fOnKeyDown write fOnKeyDown;
    property OnKeyUp: TNotifyEventKeyShiftFunc read fOnKeyUp write fOnKeyUp;

    procedure Paint; virtual;
    procedure UpdateState(aTickCount: Cardinal); virtual;
  end;


  { Panel which keeps child items in it, it's virtual and invisible }
  TKMPanel = class(TKMControl)
  private
    fMasterControl: TKMMasterControl;
    procedure Init;
  protected
    //Do not propogate SetEnabled and SetVisible because that would show/enable ALL childs childs
    //e.g. scrollbar on a listbox
    procedure SetHeight(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;
    procedure ControlMouseDown(Sender: TObject; Shift: TShiftState); override;
    procedure ControlMouseUp(Sender: TObject; Shift: TShiftState); override;
    procedure UpdateVisibility; override;
    procedure UpdateEnableStatus; override;
  public
    FocusedControlIndex: Integer; //Index of currently focused control on this Panel
    ChildCount: Word;
    Childs: array of TKMControl;
    constructor Create(aParent: TKMMasterControl; aLeft, aTop, aWidth, aHeight: Integer); overload;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer); overload;
    destructor Destroy; override;
    function AddChild(aChild: TKMControl): Integer;
    function FindFocusableControl(aFindNext: Boolean): TKMControl;
    procedure FocusNext;
    procedure ResetFocusedControlIndex;
    procedure Paint; override;

    procedure UpdateState(aTickCount: Cardinal); override;
  end;


  { Beveled area }
  TKMBevel = class(TKMControl)
  public
    BackAlpha: Single;
    EdgeAlpha: Single;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    procedure Paint; override;
  end;


  {Rectangle}
  TKMShape = class(TKMControl)
  public
    FillColor: TColor4;
    LineColor: TColor4; //color of outline
    LineWidth: Byte;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    procedure Paint; override;
  end;


  {Text Label}
  TKMLabel = class(TKMControl)
  private
    fAutoWrap: Boolean;
    fAutoCut: Boolean;
    fFont: TKMFont;
    fFontColor: TColor4; //Usually white (self-colored)
    fCaption: UnicodeString; //Original text
    fText: UnicodeString; //Reformatted text
    fTextAlign: TKMTextAlign;
    fTextSize: TKMPoint;
    fStrikethrough: Boolean;
    fTabWidth: Integer;
    function TextLeft: Integer;
    procedure SetCaption(const aCaption: UnicodeString);
    procedure SetAutoWrap(aValue: Boolean);
    procedure SetAutoCut(aValue: Boolean);
    procedure ReformatText;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aTextAlign: TKMTextAlign); overload;
    constructor Create(aParent: TKMPanel; aLeft,aTop: Integer; const aCaption: UnicodeString; aFont: TKMFont; aTextAlign: TKMTextAlign); overload;
    function HitTest(X, Y: Integer; aIncludeDisabled: Boolean = False): Boolean; override;
    property AutoWrap: Boolean read fAutoWrap write SetAutoWrap;  //Whether to automatically wrap text within given text area width
    property AutoCut: Boolean read fAutoCut write SetAutoCut;     //Whether to automatically cut text within given text area size
    property Caption: UnicodeString read fCaption write SetCaption;
    property FontColor: TColor4 read fFontColor write fFontColor;
    property Strikethrough: Boolean read fStrikethrough write fStrikethrough;
    property TabWidth: Integer read fTabWidth write fTabWidth;
    property TextSize: TKMPoint read fTextSize;
    property Font: TKMFont read fFont write fFont;
    procedure Paint; override;
  end;


  //Label that is scrolled within an area. Used in Credits
  TKMLabelScroll = class(TKMLabel)
  public
    SmoothScrollToTop: cardinal; //Delta between this and TimeGetTime affects vertical position
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aTextAlign: TKMTextAlign);
    procedure Paint; override;
  end;


  {Image}
  TKMImage = class(TKMControl)
  private
    fRX: TRXType;
    fTexID: Word;
    fFlagColor: TColor4;
  public
    ImageAnchors: TKMAnchorsSet;
    Highlight: Boolean;
    HighlightOnMouseOver: Boolean;
    Lightness: Single;
    ClipToBounds: Boolean;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID: Word; aRX: TRXType = rxGui);
    property RX: TRXType read fRX write fRX;
    property TexID: Word read fTexID write fTexID;
    property FlagColor: TColor4 read fFlagColor write fFlagColor;
    function Click: Boolean;
    procedure ImageStretch;
    procedure ImageCenter;
    procedure Paint; override;
  end;


  {Image stack - for army formation view}
  TKMImageStack = class(TKMControl)
  private
    fRX: TRXType;
    fTexID1, fTexID2: Word; //Normal and commander
    fCount: Integer;
    fColumns: Integer;
    fDrawWidth: Integer;
    fDrawHeight: Integer;
    fHighlightID: Integer;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID1, aTexID2: Word; aRX: TRXType = rxGui);
    procedure SetCount(aCount, aColumns, aHighlightID: Word);
    procedure Paint; override;
  end;


  { Color swatch - to select a color from given samples/palette }
  TKMColorSwatch = class(TKMControl)
  private
    fBackAlpha: single; //Alpha of background (usually 0.5, dropbox 1)
    fCellSize: Byte; //Size of the square in pixels
    fColumnCount: Byte;
    fRowCount: Byte;
    fColorIndex: Integer;
    Colors:array of TColor4;
    fOnChange: TNotifyEvent;
    fInclRandom: Boolean;
  public
    constructor Create(aParent: TKMPanel; aLeft,aTop,aColumnCount,aRowCount,aSize: Integer);
    procedure SetColors(const aColors: array of TColor4; aInclRandom: Boolean = False);
    procedure SelectByColor(aColor: TColor4);
    property BackAlpha: single read fBackAlpha write fBackAlpha;
    property ColorIndex: Integer read fColorIndex write fColorIndex;
    function GetColor: TColor4;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    property OnChange: TNotifyEvent write fOnChange;
    procedure Paint; override;
  end;


  {3DButton}
  TKMButton = class(TKMControl)
  private
    fTextAlign: TKMTextAlign;
    fStyle: TKMButtonStyle;
    fRX: TRXType;
  public
    Caption: UnicodeString;
    FlagColor: TColor4; //When using an image
    Font: TKMFont;
    MakesSound: Boolean;
    TexID: Word;
    CapOffsetX: Shortint;
    CapOffsetY: Shortint;
    ShowImageEnabled: Boolean; // show picture as enabled or not (normal or darkened)
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID: Word; aRX: TRXType; aStyle: TKMButtonStyle); overload;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aStyle: TKMButtonStyle); overload;
    function Click: Boolean; //Try to click a button and return TRUE if succeded
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure Paint; override;
  end;


  {Common Flat Button}
  TKMButtonFlatCommon = class(TKMControl)
  private
  public
    RX: TRXType;
    TexID: Word;
    TexOffsetX: Shortint;
    TexOffsetY: Shortint;
    CapOffsetX: Shortint;
    CapOffsetY: Shortint;
    Caption: UnicodeString;
    CapColor: TColor4;
    FlagColor: TColor4;
    Font: TKMFont;
    HideHighlight: Boolean;
    Clickable: Boolean; //Disables clicking without dimming

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight,aTexID: Integer; aRX: TRXType = rxGui);

    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    procedure Paint; override;

  end;


  {FlatButton}
  TKMButtonFlat = class(TKMButtonFlatCommon)
  public
    Down: Boolean;
    procedure Paint; override;
  end;


  {FlatButton with Shape on it}
  TKMFlatButtonShape = class(TKMControl)
  private
    fCaption: UnicodeString;
    fFont: TKMFont;
    fFontHeight: Byte;
  public
    Down: Boolean;
    FontColor: TColor4;
    ShapeColor: TColor4;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aShapeColor: TColor4);
    procedure Paint; override;
  end;


  TAllowedChars = (
    acDigits, //Only 0..9 digits, for numeric input
    acANSI7, //#33..#126 - only basic latin chars and symbols for user nikname
    acFileName, //Exclude symbols that can't be used in filenames
    acText  //Anything is allowed except for eol symbol
  );


  // Check if specified aChar is allowed for specified aAllowedChars type
  function IsCharAllowed(aChar: WideChar; aAllowedChars: TAllowedChars): Boolean;


type

  //Form that can be dragged around (and resized?)
  TKMForm = class(TKMPanel)
  private
    fHeaderHeight: Integer;
    fButtonClose: TKMButtonFlat;
    fLabelCaption: TKMLabel;

    fDragging: Boolean;
    fOffsetX: Integer;
    fOffsetY: Integer;
    function HitHeader(X, Y: Integer): Boolean;
    procedure FormCloseClick(Sender: TObject);
    function GetCaption: UnicodeString;
    procedure SetCaption(const aValue: UnicodeString);
  public
    OnMove: TNotifyEvent;
    OnClose: TNotifyEvent;

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    property Caption: UnicodeString read GetCaption write SetCaption;
    procedure MouseDown (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove (X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp   (X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure Paint; override;
  end;


  //Selectable Edit - Basic Edit class with selection available
  TKMSelectableEdit = class(TKMControl)
  private
    fFont: TKMFont;
    fLeftIndex: Integer; //The position of the character shown left-most when text does not fit

    fCursorPos: Integer;
    fSelectable: Boolean;
    fSelectionStart: Integer;
    fSelectionEnd: Integer;
    fSelectionInitialCursorPos: Integer;

    procedure SetCursorPos(aPos: Integer);
    function GetCursorPosAt(X: Integer): Integer;
    procedure ResetSelection;
    function HasSelection: Boolean;
    function GetSelectedText: UnicodeString;
    procedure SetSelectionStart(aValue: Integer);
    procedure SetSelectionEnd(aValue: Integer);
    procedure DeleteSelectedText;
  protected
    fText: UnicodeString;
    procedure ControlMouseDown(Sender: TObject; Shift: TShiftState); override;
    procedure FocusChanged(aFocused: Boolean); override;
    function GetMaxLength: Word; virtual; abstract;
    function IsCharValid(aChar: WideChar): Boolean; virtual; abstract;
    procedure ValidateText; virtual; abstract;
    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean; virtual; abstract;
    procedure PaintSelection;
  public
    ReadOnly: Boolean;
    BlockInput: Boolean; // Blocks all input into the field, but allow focus, selection and copy selected text

    OnChange: TNotifyEvent;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean = True);

    property CursorPos: Integer read fCursorPos write SetCursorPos;
    property Selectable: Boolean read fSelectable write fSelectable;
    property SelectionStart: Integer read fSelectionStart write SetSelectionStart;
    property SelectionEnd: Integer read fSelectionEnd write SetSelectionEnd;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    procedure KeyPress(Key: Char); override;
    function KeyUp(Key: Word; Shift: TShiftState): Boolean; override;
  end;

  {EditField}
  TKMEdit = class(TKMSelectableEdit)
  private
    fAllowedChars: TAllowedChars;
    procedure SetText(const aText: UnicodeString);
  protected
    function GetMaxLength: Word; override;
    function IsCharValid(aChar: WideChar): Boolean; override;
    procedure ValidateText; override;
    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean; override;
    function GetRText: UnicodeString;
  public
    Masked: Boolean; //Mask entered text as *s
    MaxLen: Word;
    ShowColors: Boolean;
    DrawOutline: Boolean;
    OutlineColor: Cardinal;
    OnIsKeyEventHandled: TNotifyEventKeyFunc; //Invoked to check is key overrides default handle policy or not
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean = True);

    property AllowedChars: TAllowedChars read fAllowedChars write fAllowedChars;
    property Text: UnicodeString read fText write SetText;

    function HitTest(X,Y: Integer; aIncludeDisabled: Boolean=false): Boolean; override;
    procedure Paint; override;
  end;


  { Checkbox }
  TKMCheckBox = class(TKMControl)
  private
    fCaption: UnicodeString;
    fChecked: Boolean;
    fFont: TKMFont;
  public
    DrawOutline: Boolean;
    LineColor: TColor4; //color of outline
    LineWidth: Byte;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont); overload;
    property Caption: UnicodeString read fCaption write fCaption;
    property Checked: Boolean read fChecked write fChecked;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure Paint; override;
  end;


  { TKMRadioGroup }
  TKMRadioGroup = class(TKMControl)
  private
    fItemIndex: Integer;
    fCount: Integer;
    fItems: array of record
      Text: UnicodeString;
      Enabled: Boolean;
    end;
    fFont: TKMFont;
    fOnChange: TNotifyEvent;
  public
    DrawChkboxOutline: Boolean;
    LineColor: TColor4; //color of outline
    LineWidth: Byte;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont);

    procedure Add(aText: UnicodeString; aEnabled: Boolean = True);
    procedure Clear;
    property Count: Integer read fCount;
    property ItemIndex: Integer read fItemIndex write fItemIndex;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure Paint; override;
  end;


  {Percent bar}
  TKMPercentBar = class(TKMControl)
  private
    fFont: TKMFont;
    fPosition: Single;
    fTextAlign: TKMTextAlign;
    fSeam: Single;
    procedure SetPosition(aValue: Single);
    procedure SetSeam(aValue: Single);
  public
    Caption, CaptionLeft, CaptionRight: UnicodeString; //CaptionLeft and CaptionRight are shown to the left and right from main Caption. Use them only with taCenter
    FontColor: TColor4;
    TextYOffset: Integer;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont = fnt_Mini);
    procedure SetCaptions(const aCaptionLeft, aCaption, aCaptionRight: UnicodeString);
    property Seam: Single read fSeam write SetSeam;
    property Position: Single read fPosition write SetPosition;
    procedure Paint; override;
  end;


  {Row with resource name and icons}
  TKMWaresRow = class(TKMButtonFlatCommon)
  public
    WareCount: Word;
    WareCntAsNumber: Boolean;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer); overload;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aClickable: Boolean); overload;
    procedure Paint; override;
  end;


  TKMNumericEdit = class(TKMSelectableEdit)
  private
    fButtonInc: TKMButton;
    fButtonDec: TKMButton;
    fValue: Integer;
    procedure ButtonClick(Sender: TObject; Shift: TShiftState);

    procedure SetValueNCheckRange(aValue: Int64);
    procedure SetValue(aValue: Integer);
    procedure SetSharedHint(const aHint: UnicodeString);
    procedure CheckValueOnUnfocus;
    procedure ClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
  protected
    procedure SetLeft(aValue: Integer); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    function GetSelfAbsLeft: Integer; override;
    function GetSelfWidth: Integer; override;
    function GetMaxLength: Word; override;
    function IsCharValid(Key: WideChar): Boolean; override;
    procedure ValidateText; override;
    procedure FocusChanged(aFocused: Boolean); override;
    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean; override;
    procedure ControlMouseDown(Sender: TObject; Shift: TShiftState); override;
  public
    ValueMin: Integer;
    ValueMax: Integer;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aValueMin, aValueMax: Integer; aFont: TKMFont = fnt_Grey; aSelectable: Boolean = True);
    property Value: Integer read fValue write SetValue;
    property SharedHint: UnicodeString read Hint write SetSharedHint;

    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    procedure MouseWheel(Sender: TObject; WheelDelta: Integer); override;
    procedure Paint; override;
  end;

  {Ware order bar}
  TKMWareOrderRow = class(TKMControl)
  private
    fWaresRow: TKMWaresRow;
    fOrderAdd: TKMButton;
    fOrderLab: TKMLabel;
    fOrderRem: TKMButton;
    fOrderCount: Integer;
    procedure ButtonClick(Sender: TObject; Shift: TShiftState);
    procedure ClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
    procedure SetOrderRemHint(aValue: UnicodeString);
    procedure SetOrderAddHint(aValue: UnicodeString);
    procedure SetOrderCount(aValue: Integer);
  protected
    procedure SetTop(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
  public
    OrderCntMin: Integer;
    OrderCntMax: Integer;
    OnChange: TObjectIntegerEvent;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aOrderCntMax: Integer = MAX_WARES_IN_HOUSE; aOrderCntMin: Integer = 0);
    property WareRow: TKMWaresRow read fWaresRow;
    property OrderCount: Integer read fOrderCount write SetOrderCount;
    property OrderRemHint: UnicodeString write SetOrderRemHint;
    property OrderAddHint: UnicodeString write SetOrderAddHint;
    procedure MouseWheel(Sender: TObject; WheelDelta: Integer); override;
    procedure Paint; override;
  end;


  {Production cost bar}
  TKMCostsRow = class(TKMControl)
  public
    RX: TRXType;
    TexID1, TexID2: Word;
    Count: Byte;
    Caption: UnicodeString;
    procedure Paint; override;
  end;


  TKMTrackBar = class(TKMControl)
  private
    fTrackTop: Byte; //Offset trackbar from top (if Caption <> '')
    fTrackHeight: Byte; //Trackbar height
    fMinValue: Word;
    fMaxValue: Word;
    fOnChange: TNotifyEvent;
    fCaption: UnicodeString;
    fPosition: Word;
    fFont: TKMFont;
    procedure SetCaption(const aValue: UnicodeString);
    procedure SetPosition(aValue: Word);
  public
    Step: Byte; //Change Position by this amount each time
    ThumbText: UnicodeString;
    ThumbWidth: Word;

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aMin, aMax: Word);

    property Caption: UnicodeString read fCaption write SetCaption;
    property Position: Word read fPosition write SetPosition;
    property Font: TKMFont read fFont write fFont;
    property MinValue: Word read fMinValue;
    property MaxValue: Word read fMaxValue;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure Paint; override;
  end;


  TScrollAxis = (sa_Vertical, sa_Horizontal);

  TKMScrollBar = class(TKMPanel)
  private
    fScrollAxis: TScrollAxis;
    fStyle: TKMButtonStyle;
    fMinValue: Integer;
    fMaxValue: Integer;
    fPosition: Integer;
    fThumbPos: Integer; //Position of the thumb
    fThumbSize: Word; //Length of the thumb
    fOffset: Integer;
    fScrollDec: TKMButton;
    fScrollInc: TKMButton;
    fOnChange: TNotifyEvent;
    procedure SetMinValue(Value: Integer);
    procedure SetMaxValue(Value: Integer);
    procedure SetPosition(Value: Integer);
    procedure IncPosition(Sender: TObject);
    procedure DecPosition(Sender: TObject);
    procedure UpdateThumbPos;
    procedure UpdateThumbSize;
  protected
    procedure SetHeight(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
  public
    BackAlpha: Single; //Alpha of background (usually 0.5, dropbox 1)
    EdgeAlpha: Single; //Alpha of background outline (usually 1)

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aScrollAxis: TScrollAxis; aStyle: TKMButtonStyle);
    property MinValue: Integer read fMinValue write SetMinValue;
    property MaxValue: Integer read fMaxValue write SetMaxValue;
    property Position: Integer read fPosition write SetPosition;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseWheel(Sender: TObject; WheelDelta: Integer); override;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    procedure Paint; override;
  end;


  TKMListBox = class(TKMControl)
  private
    fAutoHideScrollBar: Boolean;
    fBackAlpha: Single; //Alpha of background (usually 0.5, dropbox 1)
    fFont: TKMFont; //Should not be changed from inital value, it will mess up the word wrapping
    fItemHeight: Byte;
    fItemIndex: Smallint;
    fItems: TStringList;
    fSeparatorPositions: array of Integer;
    fSeparatorHeight: Byte;
    fSeparatorColor: TColor4;
    fSeparatorTexts: TStringList;
    fSeparatorFont: TKMFont;
    fScrollBar: TKMScrollBar;
    fOnChange: TNotifyEvent;
    function GetTopIndex: Integer;
    procedure SetTopIndex(aIndex: Integer);
    procedure SetBackAlpha(aValue: single);
    procedure SetItemHeight(const Value: byte);
    procedure SetAutoHideScrollBar(Value: boolean);
    procedure UpdateScrollBar;
    function GetItem(aIndex: Integer): UnicodeString;
    function GetSeparatorPos(aIndex: Integer): Integer;
    function GetItemTop(aIndex: Integer): Integer;
  protected
    procedure SetLeft(aValue: Integer); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetHeight(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    function GetSelfWidth: Integer; override;
  public
    ItemTags: array of Integer;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle);
    destructor Destroy; override;

    property AutoHideScrollBar: boolean read fAutoHideScrollBar write SetAutoHideScrollBar;
    property BackAlpha: Single write SetBackAlpha;

    procedure Add(const aItem: UnicodeString; aTag: Integer = 0);
    procedure AddSeparator(aPosition: Integer; aText: String = '');
    procedure ClearSeparators;

    procedure Clear;
    function Count: Integer;
    function SeparatorsCount: Integer;

    function GetVisibleRows: Integer;

    property Item[aIndex: Integer]: UnicodeString read GetItem; default;
    property ItemHeight: Byte read fItemHeight write SetItemHeight; //Accessed by DropBox
    property ItemIndex: Smallint read fItemIndex write fItemIndex;
    property TopIndex: Integer read GetTopIndex write SetTopIndex;

    property SeparatorPos[aIndex: Integer]: Integer read GetSeparatorPos;
    property SeparatorFont: TKMFont read fSeparatorFont write fSeparatorFont;
    property SeparatorColor: TColor4 read fSeparatorColor write fSeparatorColor;
    property SeparatorHeight: Byte read fSeparatorHeight write fSeparatorHeight;

    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    function Selected: Boolean;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseWheel(Sender: TObject; WheelDelta: Integer); override;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;

    procedure Paint; override;
  end;

  TSortDirection = (sdNone, sdUp, sdDown);

  TKMListHeaderColumn = class
    Caption: UnicodeString;
    Glyph: TKMPic;
    Offset: Word; //Offsets are easier to handle than widths
  end;

  TKMListHeader = class (TKMControl)
  private
    fFont: TKMFont;
    fCount: Integer;
    fColumns: array of TKMListHeaderColumn;
    fColumnHighlight: Integer;
    fSortIndex: Integer;
    fSortDirection: TSortDirection;
    fTextAlign: TKMTextAlign;
    function GetColumnIndex(X: Integer): Integer;
    function GetColumn(aIndex: Integer): TKMListHeaderColumn;
    procedure ClearColumns;
    function GetColumnWidth(aIndex: Integer): Integer;
  protected
    procedure DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
  public
    BackAlpha: Single; //Alpha of background
    EdgeAlpha: Single; //Alpha of background outline

    OnColumnClick: TIntegerEvent;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    destructor Destroy; override;

    procedure SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word);

    property Font: TKMFont read fFont write fFont;
    property ColumnCount: Integer read fCount;
    property Columns[aIndex: Integer]: TKMListHeaderColumn read GetColumn;
    property SortIndex: Integer read fSortIndex write fSortIndex;
    property SortDirection: TSortDirection read fSortDirection write fSortDirection;
    property TextAlign: TKMTextAlign read fTextAlign write fTextAlign;
    property ColumnWidth[aIndex: Integer]: Integer read GetColumnWidth;

    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure Paint; override;
  end;

  TKMListRow = record
    Cells: array of record
      Caption: UnicodeString;
      Hint: UnicodeString;
      Color: TColor4;
      HighlightColor: TColor4;
      HighlightOnMouseOver: Boolean;
      Enabled: Boolean;
      Pic: TKMPic;
    end;
    Tag: Integer;
  end;

  TKMListColumn = class
    Font: TKMFont;
    HintFont: TKMFont;
    TextAlign: TKMTextAlign;
    TriggerOnChange: Boolean;
  end;

  TKMColumnBox = class(TKMControl)
  private
    fFont: TKMFont;
    fBackAlpha: Single; //Alpha of background
    fEdgeAlpha: Single; //Alpha of outline
    fItemHeight: Byte;
    fItemIndex: SmallInt;
    fSearchColumn: ShortInt; //which columns text we should search, -1 for disabled
    fSearch: UnicodeString; //Contains user input characters we should search for
    fLastKeyTime: Cardinal;
    fRowCount: Integer;
    fColumns: array of TKMListColumn;
    fHeader: TKMListHeader;
    fShowHeader: Boolean;
    fShowLines: Boolean;
    fMouseOverRow: Smallint;
    fMouseOverCell: TKMPoint;
    fScrollBar: TKMScrollBar;
    fOnChange: TNotifyEvent;
    fOnCellClick: TPointEventFunc;
    function GetTopIndex: Integer;
    procedure SetTopIndex(aIndex: Integer);
    procedure SetBackAlpha(aValue: single);
    procedure SetEdgeAlpha(aValue: Single);
    function GetSortIndex: Integer;
    procedure SetSortIndex(aIndex: Integer);
    function GetSortDirection: TSortDirection;
    procedure SetSortDirection(aDirection: TSortDirection);
    procedure UpdateScrollBar;
    procedure SetShowHeader(aValue: Boolean);
    function GetOnColumnClick: TIntegerEvent;
    procedure SetOnColumnClick(const Value: TIntegerEvent);
    function GetColumn(aIndex: Integer): TKMListColumn;
    procedure ClearColumns;
    procedure SetSearchColumn(aValue: ShortInt);
    procedure SetItemIndex(const Value: Smallint);
    procedure UpdateMouseOverPosition(X,Y: Integer);
    procedure UpdateItemIndex(Shift: TShiftState);
    function GetItem(aIndex: Integer): TKMListRow;
    function GetSelectedItem: TKMListRow;
  protected
    procedure SetLeft(aValue: Integer); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;
    procedure SetHeight(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    function GetSelfAbsTop: Integer; override;
    function GetSelfHeight: Integer; override;
    function GetSelfWidth: Integer; override;
    procedure DoPaintLine(aIndex: Integer; X,Y: Integer; PaintWidth: Integer; aAllowHighlight: Boolean = True); overload;
    procedure DoPaintLine(aIndex: Integer; X, Y: Integer; PaintWidth: Integer; aColumnsToShow: array of Boolean; aAllowHighlight: Boolean = True); overload;
  public
    HideSelection: Boolean;
    HighlightError: Boolean;
    HighlightOnMouseOver: Boolean;
    Rows: array of TKMListRow; //Exposed to public since we need to edit sub-fields
    PassAllKeys: Boolean;

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle);
    destructor Destroy; override;

    property Item[aIndex: Integer]: TKMListRow read GetItem; default;
    property SelectedItem: TKMListRow read GetSelectedItem;
    procedure SetColumns(aHeaderFont: TKMFont; aCaptions: array of string; aOffsets: array of Word);
    procedure AddItem(aItem: TKMListRow);
    procedure Clear;
    function GetVisibleRows: Integer;
    function GetVisibleRowsExact: Single;
    function IsSelected: Boolean;
    property ShowHeader: Boolean read fShowHeader write SetShowHeader;
    property ShowLines: Boolean read fShowLines write fShowLines;
    property SearchColumn: ShortInt read fSearchColumn write SetSearchColumn;

    property Columns[aIndex: Integer]: TKMListColumn read GetColumn;
    property BackAlpha: Single read fBackAlpha write SetBackAlpha;
    property EdgeAlpha: Single read fEdgeAlpha write SetEdgeAlpha;
    property RowCount: Integer read fRowCount;
    property ItemHeight: Byte read fItemHeight write fItemHeight;
    property ItemIndex: Smallint read fItemIndex write SetItemIndex;
    property TopIndex: Integer read GetTopIndex write SetTopIndex;
    property Header: TKMListHeader read fHeader;

    //Sort properties are just hints to render Up/Down arrows. Actual sorting is done by client
    property OnColumnClick: TIntegerEvent read GetOnColumnClick write SetOnColumnClick;
    property OnCellClick: TPointEventFunc read fOnCellClick write fOnCellClick;
    property SortIndex: Integer read GetSortIndex write SetSortIndex;
    property SortDirection: TSortDirection read GetSortDirection write SetSortDirection;

    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    procedure KeyPress(Key: Char); override;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseWheel(Sender: TObject; WheelDelta: Integer); override;
    procedure DoClick(X, Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;

    procedure Paint; override;
  end;


  TKMDropCommon = class(TKMControl)
  private
    fDropCount: Byte;
    fDropUp: Boolean;
    fFont: TKMFont;
    fButton: TKMButton;
    fShape: TKMShape;
    fAutoClose: Boolean;

    fOnChange: TNotifyEvent;
    fOnShowList: TNotifyEvent;

    procedure UpdateDropPosition; virtual; abstract;
    procedure ButtonClick(Sender: TObject);
    procedure ListShow(Sender: TObject); virtual;
    procedure ListClick(Sender: TObject); virtual;
    procedure ListChange(Sender: TObject); virtual;
    procedure ListHide(Sender: TObject); virtual;
    function ListVisible: Boolean; virtual; abstract;
    function GetItemIndex: SmallInt; virtual; abstract;
    procedure SetItemIndex(aIndex: SmallInt); virtual; abstract;
  protected
    procedure DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure SetTop(aValue: Integer); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
    function ListKeyDown(Sender: TObject; Key: Word; Shift: TShiftState): Boolean;
    procedure UpdateVisibility; override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle; aAutoClose: Boolean = True);

    procedure Clear; virtual; abstract;
    function Count: Integer; virtual; abstract;
    procedure CloseList;

    property DropCount: Byte read fDropCount write fDropCount;
    property DropUp: Boolean read fDropUp write fDropUp;
    property ItemIndex: SmallInt read GetItemIndex write SetItemIndex;

    property OnShowList: TNotifyEvent read fOnShowList write fOnShowList;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    procedure Paint; override;
  end;


  //DropBox with a ListBox
  TKMDropList = class(TKMDropCommon)
  private
    fCaption: UnicodeString; //Current caption (Default or from list)
    fDefaultCaption: UnicodeString;
    fList: TKMListBox;
    fListTopIndex: Integer;
    procedure UpdateDropPosition; override;
    procedure ListShow(Sender: TObject); override;
    procedure ListClick(Sender: TObject); override;
    procedure ListChange(Sender: TObject); override;
    procedure ListHide(Sender: TObject); override;
    function ListVisible: Boolean; override;
    function GetItem(aIndex: Integer): UnicodeString;
    function GetItemIndex: smallint; override;
    procedure SetItemIndex(aIndex: smallint); override;
  protected
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aDefaultCaption: UnicodeString; aStyle: TKMButtonStyle; aAutoClose: Boolean = True; aBackAlpha: Single = 0.85);
    procedure Clear; override;
    function Count: Integer; override;
    procedure Add(const aItem: UnicodeString; aTag: Integer = 0);
    procedure SelectByName(const aText: UnicodeString);
    procedure SelectByTag(aTag: Integer);
    function GetTag(aIndex: Integer): Integer;
    function GetSelectedTag: Integer;
    property DefaultCaption: UnicodeString read fDefaultCaption write fDefaultCaption;
    property Item[aIndex: Integer]: UnicodeString read GetItem;
    property List: TKMListBox read fList;

    procedure Paint; override;
  end;


  //DropBox with a ColumnBox
  TKMDropColumns = class(TKMDropCommon)
  private
    fDefaultCaption: UnicodeString;
    fDropWidth: Integer;
    fList: TKMColumnBox;
    fListTopIndex: Integer;
    fColumnsToShowWhenListHidden: array of Boolean; //which columns to show, when list is hidden
    procedure UpdateDropPosition; override;
    procedure ListShow(Sender: TObject); override;
    procedure ListClick(Sender: TObject); override;
    procedure ListChange(Sender: TObject); override;
    procedure ListHide(Sender: TObject); override;
    function ListVisible: Boolean; override;
    function GetItem(aIndex: Integer): TKMListRow;
    function GetItemIndex: smallint; override;
    procedure SetItemIndex(aIndex: smallint); override;
    procedure SetDropWidth(aDropWidth:Integer);
  protected
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetVisible(aValue: Boolean); override;
  public
    FadeImageWhenDisabled: Boolean;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; const aDefaultCaption: UnicodeString; aStyle: TKMButtonStyle; aShowHeader: Boolean = True);
    procedure Add(aItem: TKMListRow);
    procedure Clear; override;
    function Count: Integer; override;
    property List: TKMColumnBox read fList;
    property Item[aIndex: Integer]: TKMListRow read GetItem;
    procedure SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word); overload;
    procedure SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word; aColumnsToShowWhenListHidden: array of Boolean); overload;
    property DefaultCaption: UnicodeString read fDefaultCaption write fDefaultCaption;
    property DropWidth: Integer read fDropWidth write SetDropWidth;

    procedure Paint; override;
  end;


  //DropBox with a ColorSwatch
  TKMDropColors = class(TKMControl)
  private
    fColorIndex: Integer;
    fRandomCaption: UnicodeString;
    fButton: TKMButton;
    fSwatch: TKMColorSwatch;
    fShape: TKMShape;
    fOnChange: TNotifyEvent;
    procedure ListShow(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure ListHide(Sender: TObject);
    procedure SetColorIndex(aIndex: Integer);
    procedure UpdateDropPosition;
  protected
    procedure SetEnabled(aValue: Boolean); override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight,aCount: Integer);
    property ColorIndex: Integer read fColorIndex write SetColorIndex;
    procedure SetColors(const aColors: array of TColor4; const aRandomCaption: UnicodeString = '');
    property OnChange: TNotifyEvent write fOnChange;
    procedure Paint; override;
  end;


  TKMMemo = class(TKMControl)
  private
    fFont: TKMFont; //Should not be changed from inital value, it will mess up the word wrapping
    fItemHeight: Byte;
    fItems: TStringList;
    fAutoWrap: Boolean;
    fIndentAfterNL: Boolean;
    fText: UnicodeString;
    fScrollDown: Boolean;
    fScrollBar: TKMScrollBar;
    fOnChange: TNotifyEvent;
    fCursorPos: Integer;
    fSelectable: Boolean;
    fSelectionStart: Integer;
    fSelectionEnd: Integer;
    fSelectionInitialPos: Integer;

    procedure SetAutoWrap(const Value: Boolean);
    function GetText: UnicodeString;
    procedure SetText(const aText: UnicodeString);
    function GetTopIndex: smallint;
    procedure SetTopIndex(aIndex: SmallInt);
    procedure ReformatText;
    procedure UpdateScrollBar;

    function KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;

    procedure SetCursorPos(aPos: Integer);
    function LinearToPointPos(aPos: Integer): TKMPoint;
    function PointToLinearPos(aColumn, aRow: Integer): Integer;
    function GetCharPosAt(X,Y: Integer): TKMPoint;
    function GetCursorPosAt(X,Y: Integer): Integer;
    procedure ResetSelection;
    function HasSelection: Boolean;
    function GetSelectedText: UnicodeString;
    function GetMaxCursorPos: Integer;
    function GetMaxPosInRow(aRow: Integer): Integer;
    function GetMinPosInRow(aRow: Integer): Integer;
    function GetMaxCursorPosInRow: Integer;
    function GetMinCursorPosInRow: Integer;
    procedure SetSelectionStart(aValue: Integer);
    procedure SetSelectionEnd(aValue: Integer);
    procedure SetSelections(aValue1, aValue2: Integer);
    procedure UpdateSelection(aPrevCursorPos: Integer);
  protected
    procedure SetHeight(aValue: Integer); override;
    procedure SetWidth(aValue: Integer); override;
    procedure SetVisible(aValue: Boolean); override;
    procedure SetEnabled(aValue: Boolean); override;
    procedure SetTop(aValue: Integer); override;
    procedure FocusChanged(aFocused: Boolean); override;
    procedure ControlMouseDown(Sender: TObject; Shift: TShiftState); override;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle; aSelectable: Boolean = True);
    destructor Destroy; override;

    procedure Add(const aItem: UnicodeString);
    procedure Clear;
    procedure ScrollToBottom;
    property AutoWrap: Boolean read fAutoWrap write SetAutoWrap; //Whether to automatically wrap text within given text area width
    property IndentAfterNL: Boolean read fIndentAfterNL write fIndentAfterNL;
    property Text: UnicodeString read GetText write SetText;
    property ItemHeight: Byte read fItemHeight write fItemHeight;
    property TopIndex: Smallint read GetTopIndex write SetTopIndex;
    property ScrollDown: Boolean read fScrollDown write fScrollDown;
    property CursorPos: Integer read fCursorPos write SetCursorPos;
    property Selectable: Boolean read fSelectable write fSelectable;
    property SelectionStart: Integer read fSelectionStart write SetSelectionStart;
    property SelectionEnd: Integer read fSelectionEnd write SetSelectionEnd;

    function GetVisibleRows: Integer;
    function KeyDown(Key: Word; Shift: TShiftState): Boolean; override;
    function KeyUp(Key: Word; Shift: TShiftState): Boolean; override;
    procedure MouseWheel(Sender: TObject; WheelDelta: Integer); override;
    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    property OnChange: TNotifyEvent read fOnChange write fOnChange;

    procedure Paint; override;
  end;


  TKMPopUpMenu = class(TKMPanel)
  private
    fShapeBG: TKMShape;
    fList: TKMColumnBox;
    procedure MenuHide(Sender: TObject);
    procedure MenuClick(Sender: TObject);
    procedure SetItemIndex(aValue: Integer);
    function GetItemIndex: Integer;
    function GetItemTag(aIndex: Integer): Integer;
  public
    constructor Create(aParent: TKMPanel; aWidth: Integer);
    procedure AddItem(const aCaption: UnicodeString; aTag: Integer = 0);
    procedure UpdateItem(aIndex: Integer; const aCaption: UnicodeString);
    procedure Clear;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property ItemTags[aIndex: Integer]: Integer read GetItemTag;
    procedure ShowAt(X,Y: Integer);
    procedure HideMenu;
  end;


  TKMPopUpPanel = class(TKMPanel)
  private
    procedure UpdateSizes;
  protected
    ImageBG: TKMImage;
    BevelBG: TKMBevel;
    procedure SetWidth(aValue: Integer); override;
    procedure SetHeight(aValue: Integer); override;
  public
    Caption: UnicodeString;
    Font: TKMFont;
    FontColor: TColor4;
    constructor Create(aParent: TKMPanel; aWidth, aHeight: Integer; const aCaption: UnicodeString = '');
    procedure Paint; override;
  end;


  TDragAxis = (daHoriz, daVertic, daAll);

  //Element that player can drag within allowed bounds
  TKMDragger = class(TKMControl)
  private
    fMinusX, fMinusY, fPlusX, fPlusY: Integer; //Restrictions
    fPositionX: Integer;
    fPositionY: Integer;
    fStartDragX: Integer;
    fStartDragY: Integer;
  public
    OnMove: TNotifyEventXY;
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);

    procedure SetBounds(aMinusX, aMinusY, aPlusX, aPlusY: Integer);

    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    procedure Paint; override;
  end;

  TKMGraphLine = record
                Title: UnicodeString;
                Tag: Integer;
                Color: TColor4;
                Visible: Boolean;
                Values: TKMCardinalArray;
                ValuesAlt: TKMCardinalArray;
              end;

  TKMChart = class(TKMControl)
  private
    fCaption: UnicodeString;
    fFont: TKMFont;
    fCount: Integer;
    fItemHeight: Byte;
    fLegendWidth: Word;
    fLegendCaption: String;
    fLineOver: Integer;
    fLines: array of TKMGraphLine;
    fMaxLength: Cardinal; //Maximum samples (by horizontal axis)
    fMinTime: Cardinal; //Minimum time (in sec), used only for Rendering time ticks
    fMaxTime: Cardinal; //Maximum time (in sec), used only for Rendering time ticks
    fMaxValue: Cardinal; //Maximum value (by vertical axis)
    fPeaceTime: Cardinal;
    fSeparatorPositions: TXStringList;
    fSeparatorHeight: Byte;
    fSeparatorColor: TColor4;
    procedure UpdateMaxValue;
    function GetLine(aIndex:Integer): TKMGraphLine;
    function GetLineNumber(aY: Integer): Integer;
//    function GetSeparatorsHeight(aIndex: Integer): Integer;
    function GetSeparatorPos(aIndex: Integer): Integer;
  public
    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
    destructor Destroy; override;

    procedure AddLine(const aTitle: UnicodeString; aColor: TColor4; const aValues: TKMCardinalArray; aTag: Integer = -1);
    procedure AddAltLine(const aAltValues: TKMCardinalArray);
    procedure TrimToFirstVariation;
    property Caption: UnicodeString read fCaption write fCaption;
    procedure Clear;
    procedure SetLineVisible(aLineID:Integer; aVisible:Boolean);
    property MaxLength: Cardinal read fMaxLength write fMaxLength;
    property MaxTime: Cardinal read fMaxTime write fMaxTime;
    property Lines[aIndex: Integer]: TKMGraphLine read GetLine;
    property LineCount:Integer read fCount;
    property Font: TKMFont read fFont write fFont;
    property LegendWidth: Word read fLegendWidth write fLegendWidth;
    property LegendCaption: String read fLegendCaption write fLegendCaption;
    property Peacetime: Cardinal read fPeaceTime write fPeaceTime;

    property SeparatorPos[aIndex: Integer]: Integer read GetSeparatorPos;
    property SeparatorColor: TColor4 read fSeparatorColor write fSeparatorColor;
    property SeparatorHeight: Byte read fSeparatorHeight write fSeparatorHeight;

    procedure AddSeparator(aPosition: Integer);
    procedure SetSeparatorPositions(aSeparatorPositions: TStringList);
    procedure ClearSeparators;

    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;

    procedure Paint; override;
  end;

  PKMChart = ^TKMChart;

  //MinimapView relies on fMinimap and fViewport that provide all the data
  //MinimapView itself is just a painter
  TKMMinimapView = class(TKMControl)
  private
    fMinimap: TKMMinimap;
    fView: TKMViewport;
    fPaintWidth: Integer;
    fPaintHeight: Integer;
    fLeftOffset: Integer;
    fTopOffset: Integer;

    fOnChange, fOnMinimapClick: TPointEvent;
    fShowLocs: Boolean;
    fLocRad: Byte;
    fClickableOnce: Boolean;
  public
    OnLocClick: TIntegerEvent;

    constructor Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);

    function LocalToMapCoords(X,Y: Integer): TKMPoint;
    function MapCoordsToLocal(X,Y: Single; const Inset: ShortInt = 0): TKMPoint;
    procedure SetMinimap(aMinimap: TKMMinimap);
    procedure SetViewport(aViewport: TKMViewport);
    property ShowLocs: Boolean read fShowLocs write fShowLocs;
    property ClickableOnce: Boolean read fClickableOnce write fClickableOnce;
    property OnChange: TPointEvent write fOnChange;
    property OnMinimapClick: TPointEvent read fOnMinimapClick write fOnMinimapClick;

    procedure MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton); override;
    procedure MouseMove(X,Y: Integer; Shift: TShiftState); override;
    procedure Paint; override;
  end;


  function MakeListRow(const aCaption: array of string; aTag: Integer = 0): TKMListRow; overload;
  function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; aTag: Integer = 0): TKMListRow; overload;
  function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; const aColorHighlight: array of TColor4; aTag: Integer = 0): TKMListRow; overload;
  function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; const aPic: array of TKMPic; aTag: Integer = 0): TKMListRow; overload;


implementation
uses
  {$IFDEF MSWindows} Windows, {$ENDIF}
  {$IFDEF Unix} LCLIntf, LCLType, {$ENDIF}
  SysUtils, StrUtils, Math, KromUtils, Clipbrd,
  KM_Resource, KM_ResSprites, KM_ResSound, KM_ResCursors,
  KM_Sound, KM_CommonUtils, KM_Utils;


const
  CLICK_HOLD_TIME_THRESHOLD = 200; // Time period, determine delay between mouse down and 1st click hold events
  WARE_ROW_HEIGHT = 21;


function MakeListRow(const aCaption: array of string; aTag: Integer = 0): TKMListRow;
var
  I: Integer;
begin
  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].Color := $FFFFFFFF;
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; aTag: Integer = 0): TKMListRow;
var I: Integer;
begin
  Assert(Length(aCaption) = Length(aColor));

  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].Color := aColor[I];
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; const aColorHighlight: array of TColor4; aTag: Integer = 0): TKMListRow;
var
  I: Integer;
begin
  Assert(Length(aCaption) = Length(aColor));
  Assert(Length(aCaption) = Length(aColorHighlight));

  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].Color := aColor[I];
    Result.Cells[I].HighlightColor := aColorHighlight[I];
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


function MakeListRow(const aCaption: array of string; const aColor: array of TColor4; const aPic: array of TKMPic; aTag: Integer = 0): TKMListRow;
var I: Integer;
begin
  Assert(Length(aCaption) = Length(aColor));
  Assert(Length(aCaption) = Length(aPic));

  SetLength(Result.Cells, Length(aCaption));

  for I := 0 to High(aCaption) do
  begin
    Result.Cells[I].Caption := aCaption[I];
    Result.Cells[I].Color := aColor[I];
    Result.Cells[I].Pic := aPic[I];
    Result.Cells[I].Enabled := True;
  end;
  Result.Tag := aTag;
end;


{ TKMControl }
constructor TKMControl.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create;
  Scale         := 1;
  Hitable       := True; //All controls can be clicked by default
  fLeft         := aLeft;
  fTop          := aTop;
  fWidth        := aWidth;
  fHeight       := aHeight;
  Anchors       := [anLeft, anTop];
  State         := [];
  fEnabled      := True;
  fVisible      := True;
  Tag           := 0;
  Hint          := '';
  fControlIndex := -1;
  AutoFocusable := True;

  if aParent <> nil then
    fID := aParent.fMasterControl.GetNextCtrlID
  else if Self is TKMPanel then
    fID := 0;

  //Parent will be Nil only for master Panel which contains all the controls in it
  fParent   := aParent;
  if aParent <> nil then
    fControlIndex := aParent.AddChild(Self);
end;


function TKMControl.KeyDown(Key: Word; Shift: TShiftState): Boolean;
var Amt: Byte;
begin
  Result := MODE_DESIGN_CONTORLS;

  if Assigned(fOnKeyDown) then
    Result := fOnKeyDown(Self, Key, Shift);

  if MODE_DESIGN_CONTORLS then
  begin
    Amt := 1;
    if ssCtrl  in Shift then Amt := 10;
    if ssShift in Shift then Amt := 100;

    if Key = VK_LEFT  then fLeft := fLeft - Amt;
    if Key = VK_RIGHT then fLeft := fLeft + Amt;
    if Key = VK_UP    then fTop  := fTop  - Amt;
    if Key = VK_DOWN  then fTop  := fTop  + Amt;
  end
end;


procedure TKMControl.KeyPress(Key: Char);
begin
  //Could be something common
end;


function TKMControl.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := False;
  if (Key = VK_TAB) and IsFocused then
  begin
    Parent.FocusNext;
    Result := True;
    Exit;
  end;

  if Assigned(fOnKeyUp) then
    Result := fOnKeyUp(Self, Key, Shift);

  if not MODE_DESIGN_CONTORLS then Exit;
end;


procedure TKMControl.ResetClickHoldMode;
begin
  if Self <> nil then // Could be nil when control is destroyes already, f.e. on game (map) exit
  begin
    fClickHoldMode := False;
    fClickHoldHandled := False;
  end;
end;


procedure TKMControl.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  //if Assigned(fOnMouseDown) then fOnMouseDown(Self); { Unused }
  fClickHoldMode := True;
  fTimeOfLastMouseDown := TimeGet;
  fLastMouseDownButton := Button;
end;


procedure TKMControl.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  //if Assigned(fOnMouseOver) then fOnMouseOver(Self); { Unused }
  if (csDown in State) then
  begin
    //Update fClickHoldMode
    if InRange(X, AbsLeft, AbsRight) and InRange(Y, AbsTop, AbsBottom) then
      fClickHoldMode := True
    else
      fClickHoldMode := False;
  end;
end;


procedure TKMControl.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  ClickHoldHandled: Boolean;
begin
  //if Assigned(fOnMouseUp) then OnMouseUp(Self); { Unused }
  if (csDown in State) then
  begin
    State := State - [csDown];
    ClickHoldHandled := fClickHoldHandled;
    ResetClickHoldMode;
    //Send Click events
    if not ClickHoldHandled then // Do not send click event, if it was handled already while in click hold mode
      DoClick(X, Y, Shift, Button);
    end;
  // No code is allowed after DoClick, as control object could be destroyed,
  // that means we will modify freed memory, which will cause memory leaks
end;


procedure TKMControl.MouseWheel(Sender: TObject; WheelDelta: Integer);
begin
  if Assigned(fOnMouseWheel) then fOnMouseWheel(Self, WheelDelta);
end;


//fVisible is checked earlier
function TKMControl.HitTest(X, Y: Integer; aIncludeDisabled: Boolean=false): Boolean;
begin
  Result := Hitable and (fEnabled or aIncludeDisabled) and InRange(X, AbsLeft, AbsLeft + fWidth) and InRange(Y, AbsTop, AbsTop + fHeight);
end;

{One common thing - draw childs for self}
procedure TKMControl.Paint;
var
  sColor: TColor4;
  Tmp: TKMPoint;
begin
  Inc(CtrlPaintCount);

  if SHOW_CONTROLS_FOCUS and (csFocus in State) then
  begin
    TKMRenderUI.WriteShape(AbsLeft-1, AbsTop-1, Width+2, Height+2, $00000000, $FF00D0FF);
    TKMRenderUI.WriteShape(AbsLeft-2, AbsTop-2, Width+4, Height+4, $00000000, $FF00D0FF);
  end;

  if SHOW_CONTROLS_ID then
    TKMRenderUI.WriteText(AbsLeft+1, AbsTop, fWidth, IntToStr(fID), fnt_Mini, taLeft);

  if not SHOW_CONTROLS_OVERLAY then exit;

  sColor := $00000000;

  if Self is TKMPanel then sColor := $200000FF;

  if Self is TKMLabel then
  begin //Special case for aligned text
    Tmp := TKMLabel(Self).TextSize;
    TKMRenderUI.WriteShape(TKMLabel(Self).TextLeft, AbsTop, Tmp.X, Tmp.Y, $4000FFFF, $80FFFFFF);
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, fWidth, fHeight, 1, $FFFFFFFF);
    TKMRenderUI.WriteShape(AbsLeft-3, AbsTop-3, 6, 6, sColor or $FF000000, $FFFFFFFF);
    Exit;
  end;

  if Self is TKMLabelScroll then
  begin //Special case for aligned text
    Tmp := TKMLabelScroll(Self).TextSize;
    TKMRenderUI.WriteShape(TKMLabelScroll(Self).TextLeft, AbsTop, Tmp.X, Tmp.Y, $4000FFFF, $80FFFFFF);
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, fWidth, fHeight, 1, $FFFFFFFF);
    TKMRenderUI.WriteShape(AbsLeft-3, AbsTop-3, 6, 6, sColor or $FF000000, $FFFFFFFF);
    Exit;
  end;

  if Self is TKMImage      then sColor := $2000FF00;
  if Self is TKMImageStack then sColor := $2080FF00;
  if Self is TKMCheckBox   then sColor := $20FF00FF;
  if Self is TKMTrackBar   then sColor := $2000FF00;
  if Self is TKMCostsRow   then sColor := $2000FFFF;
  if Self is TKMRadioGroup then sColor := $20FFFF00;

  if csOver in State then sColor := sColor OR $30000000; //Highlight on mouse over

  TKMRenderUI.WriteShape(AbsLeft, AbsTop, fWidth, fHeight, sColor, $FFFFFFFF);
  TKMRenderUI.WriteShape(AbsLeft-3, AbsTop-3, 6, 6, sColor or $FF000000, $FFFFFFFF);
end;


{Shortcuts to Controls properties}
procedure TKMControl.SetAbsLeft(aValue: Integer);
begin
  if Parent = nil then
    Left := aValue
  else
    Left := Round((aValue - Parent.AbsLeft) / Parent.Scale);
end;

procedure TKMControl.SetAbsTop(aValue: Integer);
begin
  if Parent = nil then
    Top := aValue
  else
    Top := Round((aValue - Parent.AbsTop) / Parent.Scale);
end;

function TKMControl.GetAbsBottom: Integer;
begin
  Result := GetAbsTop + GetHeight;
end;

function TKMControl.GetAbsLeft: Integer;
begin
  if Parent = nil then
    Result := Round(fLeft)
  else
    Result := Round(fLeft * Parent.Scale) + Parent.GetAbsLeft;
end;

function TKMControl.GetAbsRight: Integer;
begin
  Result := GetAbsLeft + GetWidth;
end;

function TKMControl.GetAbsTop: Integer;
begin
  if Parent = nil then
    Result := Round(fTop)
  else
    Result := Round(fTop * Parent.Scale) + Parent.GetAbsTop;
end;

function TKMControl.GetLeft: Integer;
begin
  Result := Round(fLeft)
end;

function TKMControl.GetTop: Integer;
begin
  Result := Round(fTop)
end;

function TKMControl.GetBottom: Integer;
begin
  Result := GetTop + GetHeight;
end;

function TKMControl.GetRight: Integer;
begin
  Result := GetLeft + GetWidth;
end;


procedure TKMControl.SetLeft(aValue: Integer);
begin
  fLeft := aValue;
end;

procedure TKMControl.SetTop(aValue: Integer);
begin
  fTop := aValue;
end;

function TKMControl.GetHeight: Integer;
begin
  Result := fHeight;
end;

function TKMControl.GetWidth: Integer;
begin
  Result := fWidth;
end;

function TKMControl.GetCenter: TKMPoint;
begin
  Result := KMPoint(GetLeft + (GetWidth div 2), GetTop + (GetHeight div 2));
end;


function TKMControl.GetSelfAbsLeft: Integer;
begin
  Result := AbsLeft;
end;


function TKMControl.GetSelfAbsTop: Integer;
begin
  Result := AbsTop;
end;


function TKMControl.GetSelfHeight: Integer;
begin
  Result := fHeight;
end;


function TKMControl.GetSelfWidth: Integer;
begin
  Result := fWidth;
end;


procedure TKMControl.SetTopF(aValue: Single);
begin
  //Call child classes SetTop methods
  SetTop(Round(aValue));

  //Assign actual FP value
  fTop := aValue;
end;

procedure TKMControl.SetLeftF(aValue: Single);
begin
  //Call child classes SetTop methods
  SetLeft(Round(aValue));

  //Assign actual FP value
  fLeft := aValue;
end;


function TKMControl.GetControlRect: TKMRect;
begin
  Result := KMRect(Left, Top, Left + Width, Top + Height);
end;


function TKMControl.GetIsFocused: Boolean;
begin
  Result := csFocus in State;
end;


function TKMControl.GetIsClickable: Boolean;
begin
  Result := Visible and Enabled;
end;


//Overriden in child classes
procedure TKMControl.SetHeight(aValue: Integer);
begin
  fHeight := aValue;
end;

//Overriden in child classes
procedure TKMControl.SetWidth(aValue: Integer);
begin
  fWidth := aValue;
end;


//Let the control know that it was clicked to do its internal magic
procedure TKMControl.DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  //Note that we process double-click separately (actual sequence is Click + Double-Click)
  //because we would not like to delay Click just to make sure it is single.
  //On the ther hand it does no harm to call Click first
  if (Button = mbLeft)
  and Assigned(fOnDoubleClick)
  and (GetTimeSince(fTimeOfLastClick) <= GetDoubleClickTime) then
  begin
    fTimeOfLastClick := 0;
    fOnDoubleClick(Self);
  end
  else
  begin
    if (Button = mbLeft) and Assigned(fOnDoubleClick) then
      fTimeOfLastClick := TimeGet;

    if Assigned(fOnClickShift) then
      fOnClickShift(Self, Shift)
    else
    if (Button = mbLeft) and Assigned(fOnClick) then
      fOnClick(Self)
    else
    if (Button = mbRight) and Assigned(fOnClickRight) then
      fOnClickRight(Self, X, Y);
  end;
end;


procedure TKMControl.DoClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
begin
  aHandled := False;
  //Let descendants override this method
end;


// Check Control including all its Parents to see if Control is actually displayed/visible
function TKMControl.GetVisible: Boolean;
begin
  Result := fVisible and ((Parent = nil) or Parent.Visible);
end;


procedure TKMControl.SetEnabled(aValue: Boolean);
var
  OldEnabled: Boolean;
begin
  OldEnabled := fEnabled;
  fEnabled := aValue;

  // Only swap focus if enability changed
  if (OldEnabled <> Enabled) and (Focusable or (Self is TKMPanel)) then
    MasterParent.fMasterControl.UpdateFocus(Self);

  UpdateEnableStatus;
end;


procedure TKMControl.SetAnchors(aValue: TKMAnchorsSet);
begin
  fAnchors := aValue;
end;


procedure TKMControl.SetVisible(aValue: Boolean);
var
  OldVisible: Boolean;
begin
  OldVisible := fVisible;
  fVisible := aValue;

  //Only swap focus if visibility changed
  if (OldVisible <> fVisible) and (Focusable or (Self is TKMPanel)) then
    MasterParent.fMasterControl.UpdateFocus(Self);

  UpdateVisibility;
end;


procedure TKMControl.UpdateState(aTickCount: Cardinal);
var
  SameMouseBtn: Boolean;
begin
  if (csDown in State) and fClickHoldMode and (GetTimeSince(fTimeOfLastMouseDown) > CLICK_HOLD_TIME_THRESHOLD)  then
  begin
    SameMouseBtn := False;
    case fLastMouseDownButton of
      mbLeft:   SameMouseBtn := (GetKeyState(VK_LBUTTON) < 0);
      mbRight:  SameMouseBtn := (GetKeyState(VK_RBUTTON) < 0);
    end;
    if SameMouseBtn then
    begin
      DoClickHold(Self, fLastMouseDownButton, fClickHoldHandled);
      if Assigned(fOnClickHold) then
        fOnClickHold(Self, fLastMouseDownButton, fClickHoldHandled);
    end else
      ResetClickHoldMode; //Can happen if user alt-tab from game window while holding MB. Reset Click Hold mode then
  end;

end;


procedure TKMControl.UpdateVisibility;
begin
  if Assigned(fOnChangeVisibility) then
    fOnChangeVisibility(fVisible);
  //Let descendants override this method
end;


procedure TKMControl.UpdateEnableStatus;
begin
  if Assigned(fOnChangeEnableStatus) then
    fOnChangeEnableStatus(fEnabled);
  //Let descendants override this method
end;


procedure TKMControl.FocusChanged(aFocused: Boolean);
begin
  //Let descendants override this method
end;


procedure TKMControl.ControlMouseDown(Sender: TObject; Shift: TShiftState);
begin
  //Let descendants override this method
end;


procedure TKMControl.ControlMouseUp(Sender: TObject; Shift: TShiftState);
begin
  //Let descendants override this method
end;


procedure TKMControl.Enable;  begin SetEnabled(True);  end; //Overrides will be set too
procedure TKMControl.Disable; begin SetEnabled(False); end;


// Show up entire branch in which control resides
procedure TKMControl.Show;
begin
  if Parent <> nil then Parent.Show;
  Visible := True;
end;


procedure TKMControl.Hide;
begin
  Visible := False;
end;


procedure TKMControl.AnchorsCenter;
begin
  Anchors := [];
end;


procedure TKMControl.AnchorsStretch;
begin
  Anchors := [anLeft, anTop, anRight, anBottom];
end;


procedure TKMControl.Focus;
begin
  if not IsFocused and Focusable and AutoFocusable then
  begin
    // Reset master control focus
    Parent.fMasterControl.CtrlFocus := nil;
    Parent.FocusedControlIndex := ControlIndex;
    Parent.fMasterControl.UpdateFocus(Parent);
  end;
end;


procedure TKMControl.Unfocus;
begin
  Parent.fMasterControl.CtrlFocus := nil;
end;


function TKMControl.MasterParent: TKMPanel;
var
  P: TKMPanel;
begin
  if not (Self is TKMPanel) then
    P := Parent
  else
    P := TKMPanel(Self);

  while P.Parent <> nil do
    P := P.Parent;
  Result := P;
end;


{ TKMPanel } //virtual panels that contain child items
constructor TKMPanel.Create(aParent: TKMMasterControl; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(nil, aLeft, aTop, aWidth, aHeight);

  fMasterControl := aParent;
  aParent.fMasterPanel := Self;
  Init;
end;


constructor TKMPanel.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fMasterControl := aParent.fMasterControl;
  Init;
end;


procedure TKMPanel.Init;
begin
  ResetFocusedControlIndex;
end;


procedure TKMPanel.ResetFocusedControlIndex;
begin
  FocusedControlIndex := -1;
end;


destructor TKMPanel.Destroy;
var
  I: Integer;
begin
  for I := 0 to ChildCount - 1 do
    Childs[I].Free;

  inherited;
end;


function TKMPanel.FindFocusableControl(aFindNext: Boolean): TKMControl;
var
  I, CtrlToFocusI: Integer;
begin
  Result := nil;
  CtrlToFocusI := -1;
  for I := 0 to ChildCount - 1 do
    if fMasterControl.IsAutoFocusAllowed(Childs[I]) and (
      (FocusedControlIndex = -1)                          // If FocusControl was not set (no focused element on panel)
      or (FocusedControlIndex = Childs[I].ControlIndex) // We've found last focused Control
      or (CtrlToFocusI <> -1)) then                         // We did find last focused Control on previos iterations
    begin
      //Do we need to find next focusable control ?
      if aFindNext and (CtrlToFocusI = -1) 
        //FocusedControlIndex = -1 means there is no focus on this panel. Then we need to focus on first good control
        and (FocusedControlIndex <> -1) then 
      begin
        CtrlToFocusI := I;
        Continue;
      end else begin
        Result := Childs[I]; // We find Control to focus on, then exit
        Exit;
      end;
    end;

  // If we did not find Control to focus on, try to find in the first controls of Panel (let's cycle the search)
  if CtrlToFocusI <> -1 then
  begin
    // We will try to find it until the same Control, that we find before in previous For cycle
    for I := 0 to CtrlToFocusI do // So if there will be no proper controls, then set focus again to same control with I = CtrlToFocusI
      if fMasterControl.IsAutoFocusAllowed(Childs[I]) then
      begin
        Result := Childs[I];
        Exit;
      end;
  end;
end;


//Focus next focusable control on this Panel
procedure TKMPanel.FocusNext;
var Ctrl: TKMControl;
begin
  if InRange(FocusedControlIndex, 0, ChildCount - 1) then
  begin
    Ctrl := FindFocusableControl(True);
    if Ctrl <> nil then
      FocusedControlIndex := Ctrl.ControlIndex; // update FocusedControlIndex to let fCollection.UpdateFocus focus on it
    //Need to update Focus only through UpdateFocus
    fMasterControl.UpdateFocus(Self);
  end;
end;


function TKMPanel.AddChild(aChild: TKMControl): Integer;
begin
  if ChildCount >= Length(Childs) then
    SetLength(Childs, ChildCount + 16);

  Childs[ChildCount] := aChild;
  Result := ChildCount;
  Inc(ChildCount);
end;


procedure TKMPanel.SetHeight(aValue: Integer);
var
  I: Integer;
begin
  for I := 0 to ChildCount - 1 do
    if (anTop in Childs[I].Anchors) and (anBottom in Childs[I].Anchors) then
      Childs[I].Height := Childs[I].Height + (aValue - fHeight)
    else
    if anTop in Childs[I].Anchors then
      //Do nothing
    else
    if anBottom in Childs[I].Anchors then
      Childs[I].SetTopF(Childs[I].fTop + (aValue - fHeight))
    else
      Childs[I].SetTopF(Childs[I].fTop + (aValue - fHeight) / 2);

  inherited;
end;


procedure TKMPanel.SetWidth(aValue: Integer);
var
  I: Integer;
begin
  for I := 0 to ChildCount - 1 do
    if (anLeft in Childs[I].Anchors) and (anRight in Childs[I].Anchors) then
      Childs[I].Width := Childs[I].Width + (aValue - fWidth)
    else
    if anLeft in Childs[I].Anchors then
      //Do nothing
    else
    if anRight in Childs[I].Anchors then
      Childs[I].SetLeftF(Childs[I].fLeft + (aValue - fWidth))
    else
      Childs[I].SetLeftF(Childs[I].fLeft + (aValue - fWidth) / 2);

  inherited;
end;


procedure TKMPanel.ControlMouseDown(Sender: TObject; Shift: TShiftState);
var I: Integer;
begin
  inherited;
  for I := 0 to ChildCount - 1 do
    Childs[I].ControlMouseDown(Sender, Shift);
end;


procedure TKMPanel.ControlMouseUp(Sender: TObject; Shift: TShiftState);
var I: Integer;
begin
  inherited;
  for I := 0 to ChildCount - 1 do
    Childs[I].ControlMouseUp(Sender, Shift);
end;


procedure TKMPanel.UpdateState(aTickCount: Cardinal);
var I: Integer;
begin
  for I := 0 to ChildCount - 1 do
    Childs[I].UpdateState(aTickCount);
end;


procedure TKMPanel.UpdateVisibility;
var I: Integer;
begin
  inherited;
  for I := 0 to ChildCount - 1 do
    Childs[I].UpdateVisibility;
end;


procedure TKMPanel.UpdateEnableStatus;
var I: Integer;
begin
  inherited;
  for I := 0 to ChildCount - 1 do
    Childs[I].UpdateEnableStatus;
end;



{Panel Paint means to Paint all its childs}
procedure TKMPanel.Paint;
var
  I: Integer;
begin
  inherited;
  for I := 0 to ChildCount - 1 do
    if Childs[I].fVisible then
      Childs[I].Paint;
end;


// Check if specified aChar is allowed for specified aAllowedChars type
function IsCharAllowed(aChar: WideChar; aAllowedChars: TAllowedChars): Boolean;
const
  NonFileChars: TSetOfAnsiChar = [#0 .. #31, '<', '>', #176, '|', '"', '\', '/', ':', '*', '?'];
  NonTextChars: TSetOfAnsiChar = [#0 .. #31, #176, '|']; //° has negative width so acts like a backspace in KaM fonts
begin
  Result := not ((aAllowedChars = acDigits) and not InRange(Ord(aChar), 48, 57)
    or (aAllowedChars = acANSI7) and not InRange(Ord(aChar), 32, 126)
    or (aAllowedChars = acFileName) and CharInSet(aChar, NonFileChars)
    or (aAllowedChars = acText) and CharInSet(aChar, NonTextChars));
end;


{ TKMForm }
constructor TKMForm.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fHeaderHeight := 24;

  fButtonClose := TKMButtonFlat.Create(Self, aWidth - fHeaderHeight + 2, 2, fHeaderHeight-4, fHeaderHeight-4, 340, rxGui);
  fButtonClose.OnClick := FormCloseClick;
  fLabelCaption := TKMLabel.Create(Self, 0, 5, aWidth, fHeaderHeight, 'Form1', fnt_Outline, taCenter);
  fLabelCaption.Hitable := False;
end;


procedure TKMForm.FormCloseClick(Sender: TObject);
begin
  Hide;

  if Assigned(OnClose) then
    OnClose(Self);
end;


function TKMForm.GetCaption: UnicodeString;
begin
  Result := fLabelCaption.Caption;
end;


procedure TKMForm.SetCaption(const aValue: UnicodeString);
begin
  fLabelCaption.Caption := aValue;
end;


function TKMForm.HitHeader(X, Y: Integer): Boolean;
begin
  Result := InRange(X - AbsLeft, 0, Width) and InRange(Y - AbsTop, 0, fHeaderHeight);
end;


procedure TKMForm.MouseDown(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;

  if HitHeader(X,Y) then
  begin
    fDragging := True;
    fOffsetX := X - AbsLeft;
    fOffsetY := Y - AbsTop;
  end;

  MouseMove(X, Y, Shift);
end;


procedure TKMForm.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  inherited;

  if fDragging and (csDown in State) then
  begin
    AbsLeft := EnsureRange(X - fOffsetX, 0, MasterParent.Width - Width);
    AbsTop := EnsureRange(Y - fOffsetY, 0, MasterParent.Height - Height);

    if Assigned(OnMove) then
      OnMove(Self);
  end;
end;


procedure TKMForm.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  MouseMove(X,Y,Shift);

end;


procedure TKMForm.Paint;
begin
  TKMRenderUI.WriteShadow(AbsLeft, AbsTop, Width, Height, 15, $40000000);

  TKMRenderUI.WriteOutline(AbsLeft, AbsTop, Width, Height, 3, $FF000000);
  TKMRenderUI.WriteOutline(AbsLeft+1, AbsTop+1, Width-2, Height-2, 1, $FF80FFFF);

  inherited;
end;


{ TKMBevel }
constructor TKMBevel.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  BackAlpha := 0.4; //Default value
  EdgeAlpha := 0.75; //Default value
end;


procedure TKMBevel.Paint;
begin
  inherited;
  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height, EdgeAlpha, BackAlpha);
end;


{ TKMShape }
constructor TKMShape.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  LineWidth := 2;
end;


procedure TKMShape.Paint;
begin
  inherited;
  TKMRenderUI.WriteShape(AbsLeft, AbsTop, Width, Height, FillColor);
  TKMRenderUI.WriteOutline(AbsLeft, AbsTop, Width, Height, LineWidth, LineColor);
end;


{ TKMLabel }
constructor TKMLabel.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aTextAlign: TKMTextAlign);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont := aFont;
  fFontColor := $FFFFFFFF;
  fTextAlign := aTextAlign;
  fAutoWrap := False;
  fTabWidth := TAB_WIDTH;
  SetCaption(aCaption);
end;


//Same as above but with width/height ommitted, as in most cases we don't know/don't care
constructor TKMLabel.Create(aParent: TKMPanel; aLeft, aTop: Integer; const aCaption: UnicodeString; aFont: TKMFont; aTextAlign: TKMTextAlign);
begin
  Create(aParent, aLeft, aTop, 0, 0, aCaption, aFont, aTextAlign);
end;


function TKMLabel.TextLeft: Integer;
begin
  case fTextAlign of
    taLeft:   Result := AbsLeft;
    taCenter: Result := AbsLeft + Round((Width - fTextSize.X) / 2);
    taRight:  Result := AbsLeft + (Width - fTextSize.X);
    else      Result := AbsLeft;
  end;
end;


procedure TKMLabel.SetCaption(const aCaption: UnicodeString);
begin
  fCaption := aCaption;
  ReformatText;
end;


procedure TKMLabel.SetAutoCut(aValue: Boolean);
begin
  fAutoCut := aValue;
  ReformatText;
end;


procedure TKMLabel.SetAutoWrap(aValue: Boolean);
begin
  fAutoWrap := aValue;
  ReformatText;
end;


//Override usual hittest with regard to text alignment
function TKMLabel.HitTest(X, Y: Integer; aIncludeDisabled: Boolean=false): Boolean;
begin
  Result := Hitable and InRange(X, TextLeft, TextLeft + fTextSize.X) and InRange(Y, AbsTop, AbsTop + Height);
end;


//Existing EOLs should be preserved, and new ones added where needed
//Keep original intact incase we need to Reformat text once again
procedure TKMLabel.ReformatText;
  procedure Reformat;
  begin
    if fAutoWrap then
      fText := gRes.Fonts[fFont].WordWrap(fCaption, Width, True, False)
    else
      fText := fCaption;

    fTextSize := gRes.Fonts[fFont].GetTextSize(fText);
  end;
begin
  Reformat;
  // Automatically cut text symbol by symbol until it will fit into given sizes (width and height)
  if fAutoCut then
    while (Length(fCaption) > 0)
      and (((fTextSize.X > Width) and (Width > 0))
      or ((fTextSize.Y > Height) and (Height > 0))) do
    begin
      fCaption := Copy(fCaption, 1, Length(fCaption) - 1);
      Reformat;
    end;
end;


// Send caption to render
procedure TKMLabel.Paint;
var
  Col: Cardinal;
begin
  inherited;

  if fEnabled then Col := FontColor
              else Col := $FF888888;

  TKMRenderUI.WriteText(AbsLeft, AbsTop, Width, fText, fFont, fTextAlign, Col, False, False, fTabWidth);

  if fStrikethrough then
    TKMRenderUI.WriteShape(TextLeft, AbsTop + fTextSize.Y div 2 - 2, fTextSize.X, 3, Col, $FF000000);
end;


{ TKMLabelScroll }
constructor TKMLabelScroll.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aTextAlign: TKMTextAlign);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aCaption, aFont, aTextAlign);
  SmoothScrollToTop := 0; //Disabled by default
end;


procedure TKMLabelScroll.Paint;
var NewTop: Integer; Col: Cardinal;
begin
  TKMRenderUI.SetupClipY(AbsTop, AbsTop + Height);
  NewTop := EnsureRange(AbsTop + Height - GetTimeSince(SmoothScrollToTop) div 50, -MINSHORT, MAXSHORT); //Compute delta and shift by it upwards (Credits page)

  if fEnabled then Col := FontColor
              else Col := $FF888888;

  TKMRenderUI.WriteText(AbsLeft, NewTop, Width, fCaption, fFont, fTextAlign, Col);
  TKMRenderUI.ReleaseClipY;
end;


{ TKMImage }
constructor TKMImage.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID: Word; aRX: TRXType = rxGui);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fRX := aRX;
  fTexID := aTexID;
  fFlagColor := $FFFF00FF;
  ImageAnchors := [anLeft, anTop];
  Highlight := false;
  HighlightOnMouseOver := false;
end;


//DoClick is called by keyboard shortcuts
//It's important that Control must be:
// IsVisible (can't shortcut invisible/unaccessible button)
// Enabled (can't shortcut disabled function, e.g. Halt during fight)
function TKMImage.Click: Boolean;
begin
  if Visible and fEnabled then
  begin
    //Mark self as CtrlOver and CtrlUp, don't mark CtrlDown since MouseUp manually Nils it
    Parent.fMasterControl.CtrlOver := Self;
    Parent.fMasterControl.CtrlUp := Self;
    if Assigned(fOnClick) then fOnClick(Self);
    Result := true; //Click has happened
  end
  else
    Result := False; //No, we couldn't click for Control is unreachable
end;


procedure TKMImage.ImageStretch;
begin
  ImageAnchors := [anLeft, anRight, anTop, anBottom]; //Stretch image to fit
end;


procedure TKMImage.ImageCenter; //Render image from center
begin
  ImageAnchors := [];
end;


{If image area is bigger than image - do center image in it}
procedure TKMImage.Paint;
var
  PaintLightness: Single;
begin
  inherited;
  if fTexID = 0 then Exit; //No picture to draw

  if ClipToBounds then
  begin
    TKMRenderUI.SetupClipX(AbsLeft, AbsLeft + Width);
    TKMRenderUI.SetupClipY(AbsTop,  AbsTop + Height);
  end;

  PaintLightness := Lightness + 0.4 * (Byte(HighlightOnMouseOver and (csOver in State)) + Byte(Highlight));

  TKMRenderUI.WritePicture(AbsLeft, AbsTop, fWidth, fHeight, ImageAnchors, fRX, fTexID, fEnabled, fFlagColor, PaintLightness);
  TKMRenderUI.ReleaseClipX;
  TKMRenderUI.ReleaseClipY;
end;


{ TKMImageStack }
constructor TKMImageStack.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID1, aTexID2: Word; aRX: TRXType = rxGui);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fRX  := aRX;
  fTexID1 := aTexID1;
  fTexID2 := aTexID2;
end;


procedure TKMImageStack.SetCount(aCount, aColumns, aHighlightID: Word);
var
  Aspect: Single;
begin
  fCount := aCount;
  fColumns := Math.max(1, aColumns);
  fHighlightID := aHighlightID;

  fDrawWidth  := EnsureRange(Width div fColumns, 8, GFXData[fRX, fTexID1].PxWidth);
  fDrawHeight := EnsureRange(Height div Ceil(fCount/fColumns), 6, GFXData[fRX, fTexID1].PxHeight);

  Aspect := GFXData[fRX, fTexID1].PxWidth / GFXData[fRX, fTexID1].PxHeight;
  if fDrawHeight * Aspect <= fDrawWidth then
    fDrawWidth  := Round(fDrawHeight * Aspect)
  else
    fDrawHeight := Round(fDrawWidth / Aspect);
end;


// If image area is bigger than image - do center image in it
procedure TKMImageStack.Paint;
var
  I: Integer;
  OffsetX, OffsetY, CenterX, CenterY: SmallInt; //variable parameters
  texID: Word;
begin
  inherited;
  if fTexID1 = 0 then Exit; //No picture to draw

  OffsetX := Width div fColumns;
  OffsetY := Height div Ceil(fCount / fColumns);

  CenterX := (Width - OffsetX * (fColumns-1) - fDrawWidth) div 2;
  CenterY := (Height - OffsetY * (Ceil(fCount/fColumns) - 1) - fDrawHeight) div 2;

  for I := 0 to fCount - 1 do
  begin
    texID := IfThen(I = fHighlightID, fTexID2, fTexId1);

    TKMRenderUI.WritePicture(AbsLeft + CenterX + OffsetX * (I mod fColumns),
                            AbsTop + CenterY + OffsetY * (I div fColumns),
                            fDrawWidth, fDrawHeight, [anLeft, anTop, anRight, anBottom], fRX, texID, fEnabled);
  end;
end;


{ TKMColorSwatch }
constructor TKMColorSwatch.Create(aParent: TKMPanel; aLeft,aTop,aColumnCount,aRowCount,aSize: Integer);
begin
  inherited Create(aParent, aLeft, aTop, 0, 0);

  fBackAlpha    := 0.5;
  fColumnCount  := aColumnCount;
  fRowCount     := aRowCount;
  fCellSize     := aSize;
  fInclRandom   := false;
  fColorIndex   := -1;

  Width  := fColumnCount * fCellSize;
  Height := fRowCount * fCellSize;
end;


procedure TKMColorSwatch.SetColors(const aColors: array of TColor4; aInclRandom: Boolean = False);
begin
  fInclRandom := aInclRandom;
  if fInclRandom then
  begin
    SetLength(Colors, Length(aColors)+SizeOf(TColor4));
    Colors[0] := $00000000; //This one is reserved for random
    Move((@aColors[0])^, (@Colors[1])^, SizeOf(aColors));
  end
  else
  begin
    SetLength(Colors, Length(aColors));
    Move((@aColors[0])^, (@Colors[0])^, SizeOf(aColors));
  end;
end;


procedure TKMColorSwatch.SelectByColor(aColor: TColor4);
var I: Integer;
begin
  fColorIndex := -1;
  for I:=0 to Length(Colors)-1 do
    if Colors[I] = aColor then
      fColorIndex := I;
end;


function TKMColorSwatch.GetColor: TColor4;
begin
  if fColorIndex <> -1 then
    Result := Colors[fColorIndex]
  else
    Result := $FF000000; //Black by default
end;


procedure TKMColorSwatch.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var NewColor: Integer;
begin
  if Button = mbLeft then
  begin
    NewColor := EnsureRange((Y-AbsTop) div fCellSize, 0, fRowCount-1)*fColumnCount +
                EnsureRange((X-AbsLeft) div fCellSize, 0, fColumnCount-1);
    if InRange(NewColor, 0, Length(Colors)-1) then
    begin
      fColorIndex := NewColor;
      if Assigned(fOnChange) then fOnChange(Self);
    end;
  end;

  inherited;
end;


procedure TKMColorSwatch.Paint;
var i,Start: Integer;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height, 1, fBackAlpha);

  Start := 0;
  if fInclRandom then
  begin
    //Render miniature copy of all available colors with '?' on top
    for i:=0 to Length(Colors)-1 do
      TKMRenderUI.WriteShape(AbsLeft+(i mod fColumnCount)*(fCellSize div fColumnCount)+2, AbsTop+(i div fColumnCount)*(fCellSize div fColumnCount)+2, (fCellSize div fColumnCount), (fCellSize div fColumnCount), Colors[i]);
    TKMRenderUI.WriteText(AbsLeft + fCellSize div 2, AbsTop + fCellSize div 4, 0, '?', fnt_Metal, taCenter);
    Start := 1;
  end;

  for i:=Start to Length(Colors)-1 do
    TKMRenderUI.WriteShape(AbsLeft+(i mod fColumnCount)*fCellSize, AbsTop+(i div fColumnCount)*fCellSize, fCellSize, fCellSize, Colors[i]);

  //Paint selection
  if fColorIndex <> -1 then
    TKMRenderUI.WriteOutline(AbsLeft+(fColorIndex mod fColumnCount)*fCellSize, AbsTop+(fColorIndex div fColumnCount)*fCellSize, fCellSize, fCellSize, 1, $FFFFFFFF);
end;


{ TKMButton }
constructor TKMButton.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aTexID: Word; aRX: TRXType; aStyle: TKMButtonStyle);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fRX          := aRX;
  TexID        := aTexID;
  Caption      := '';
  FlagColor    := $FFFF00FF;
  fStyle       := aStyle;
  MakesSound   := True;
  ShowImageEnabled := True;
end;


{Different version of button, with caption on it instead of image}
constructor TKMButton.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aStyle: TKMButtonStyle);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  TexID        := 0;
  Caption      := aCaption;
  FlagColor    := $FFFF00FF;
  Font         := fnt_Metal;
  fTextAlign   := taCenter; //Thats default everywhere in KaM
  fStyle       := aStyle;
  MakesSound   := True;
  ShowImageEnabled := True;
end;


//DoClick is called by keyboard shortcuts
//It puts a focus on the button and depresses it if it was DoPress'ed
//It's important that Control must be:
// Visible (can't shortcut invisible/unaccessible button)
// Enabled (can't shortcut disabled function, e.g. Halt during fight)
function TKMButton.Click: Boolean;
begin
  if Visible and fEnabled then
  begin
    //Mark self as CtrlOver and CtrlUp, don't mark CtrlDown since MouseUp manually Nils it
    Parent.fMasterControl.CtrlOver := Self;
    Parent.fMasterControl.CtrlUp := Self;
    if Assigned(fOnClick) then fOnClick(Self);
    Result := true; //Click has happened
  end
  else
    Result := false; //No, we couldn't click for Control is unreachable
end;


procedure TKMButton.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if fEnabled and MakesSound and (csDown in State) then
    gSoundPlayer.Play(sfxn_ButtonClick);

  inherited;
end;


procedure TKMButton.Paint;
var
  Col: TColor4;
  StateSet: TKMButtonStateSet;
begin
  inherited;
  StateSet := [];
  if (csOver in State) and fEnabled then
    StateSet := StateSet + [bsOver];
  if (csOver in State) and (csDown in State) then
    StateSet := StateSet + [bsDown];
  if not fEnabled then
    StateSet := StateSet + [bsDisabled];

  TKMRenderUI.Write3DButton(AbsLeft, AbsTop, Width, Height, fRX, TexID, FlagColor, StateSet, fStyle, ShowImageEnabled);

  if TexID <> 0 then Exit;

  //If disabled then text should be faded
  Col := IfThen(fEnabled, icWhite, icGray);

  TKMRenderUI.WriteText(AbsLeft + Byte(csDown in State) + CapOffsetX,
                      (AbsTop + Height div 2) - 7 + Byte(csDown in State) + CapOffsetY,
                      Width, Caption, Font, fTextAlign, Col);
end;


{TKMButtonFlatCommon}
constructor TKMButtonFlatCommon.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight, aTexID: Integer; aRX: TRXType = rxGui);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  RX        := aRX;
  TexID     := aTexID;
  FlagColor := $FFFF00FF;
  CapColor  := $FFFFFFFF;
  Font      := fnt_Game;
  Clickable := True;
end;


procedure TKMButtonFlatCommon.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if not Clickable then Exit;
  if fEnabled and (csDown in State) then
    gSoundPlayer.Play(sfx_Click);

  inherited;
end;


procedure TKMButtonFlatCommon.Paint;
const
  TextCol: array [Boolean] of TColor4 = ($FF808080, $FFFFFFFF);
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height);

  if (csOver in State) and fEnabled and not HideHighlight then
    TKMRenderUI.WriteShape(AbsLeft+1, AbsTop+1, Width-2, Height-2, $40FFFFFF);
end;


//Simple version of button, with a caption and image
{TKMButtonFlat}
procedure TKMButtonFlat.Paint;
const
  TextCol: array [Boolean] of TColor4 = ($FF808080, $FFFFFFFF);
begin
  inherited;

  if TexID <> 0 then
    TKMRenderUI.WritePicture(AbsLeft + TexOffsetX,
                             AbsTop + TexOffsetY - 6 * Byte(Caption <> ''),
                             Width, Height, [], RX, TexID, fEnabled, FlagColor);

  TKMRenderUI.WriteText(AbsLeft + CapOffsetX, AbsTop + (Height div 2) + 4 + CapOffsetY, Width, Caption, Font, taCenter, TextCol[fEnabled]);

  if Down then
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, Width, Height, 1, $FFFFFFFF);
  {if not fEnabled then
    TKMRenderUI.WriteShape(Left, Top, Width, Height, $80000000);}
end;


{ TKMFlatButtonShape }
constructor TKMFlatButtonShape.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont; aShapeColor: TColor4);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fCaption    := aCaption;
  ShapeColor  := aShapeColor;
  fFont       := aFont;
  fFontHeight := gRes.Fonts[fFont].BaseHeight + 2;
  FontColor   := icWhite;
end;


procedure TKMFlatButtonShape.Paint;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height);

  //Shape within bevel
  TKMRenderUI.WriteShape(AbsLeft + 1, AbsTop + 1, Width - 2, Width - 2, ShapeColor);

  TKMRenderUI.WriteText(AbsLeft, AbsTop + (Height - fFontHeight) div 2,
                      Width, fCaption, fFont, taCenter, FontColor);

  if (csOver in State) and fEnabled then
    TKMRenderUI.WriteShape(AbsLeft + 1, AbsTop + 1, Width - 2, Height - 2, $40FFFFFF);

  if (csDown in State) or Down then
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, Width, Height, 1, icWhite);
end;


{ TKMSelectableEdit }
constructor TKMSelectableEdit.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont := aFont;
  CursorPos := 0;

  //Text input fields are focusable by concept
  Focusable := True;
  ReadOnly := False;
  BlockInput := False;
  fSelectable := aSelectable;

  //fOnControlMouseDown := ControlMouseDown;
end;


procedure TKMSelectableEdit.DeleteSelectedText;
begin
  Delete(fText, fSelectionStart+1, fSelectionEnd-fSelectionStart);
  if CursorPos = fSelectionEnd then
    CursorPos := CursorPos - (fSelectionEnd-fSelectionStart);
  ResetSelection;
end;


function TKMSelectableEdit.GetCursorPosAt(X: Integer): Integer;
var RText: UnicodeString;
begin
  RText := Copy(fText, fLeftIndex+1, Length(fText) - fLeftIndex);
  if gRes.Fonts[fFont].GetTextSize(RText).X < X-SelfAbsLeft-4 then
    Result := Length(RText) + fLeftIndex
  else
    Result := gRes.Fonts[fFont].CharsThatFit(RText, X-SelfAbsLeft-4) + fLeftIndex;
end;


function TKMSelectableEdit.GetSelectedText: UnicodeString;
begin
  Result := '';
  if HasSelection then
    Result := Copy(fText, fSelectionStart+1, fSelectionEnd - fSelectionStart);
end;


function TKMSelectableEdit.HasSelection: Boolean;
begin
  Result := (fSelectionStart <> -1) and (fSelectionEnd <> -1) and (fSelectionStart <> fSelectionEnd);
end;


procedure TKMSelectableEdit.ResetSelection;
begin
  fSelectionStart := -1;
  fSelectionEnd := -1;
  fSelectionInitialCursorPos := -1;
end;


procedure TKMSelectableEdit.SetSelectionEnd(aValue: Integer);
begin
  if fSelectable then
    fSelectionEnd := EnsureRange(aValue, 0, Length(fText));
end;


procedure TKMSelectableEdit.SetSelectionStart(aValue: Integer);
begin
  if fSelectable then
    fSelectionStart := EnsureRange(aValue, 0, Length(fText));
end;


procedure TKMSelectableEdit.SetCursorPos(aPos: Integer);
var
  RText: UnicodeString;
begin
  fCursorPos := EnsureRange(aPos, 0, Length(fText));
  if fCursorPos < fLeftIndex then
    fLeftIndex := fCursorPos
  else
  begin
    //Remove characters to the left of fLeftIndex
    RText := Copy(fText, fLeftIndex+1, Length(fText));
    while fCursorPos-fLeftIndex > gRes.Fonts[fFont].CharsThatFit(RText, Width-8) do
    begin
      Inc(fLeftIndex);
      //Remove characters to the left of fLeftIndex
      RText := Copy(fText, fLeftIndex+1, Length(fText));
    end;
  end;
end;


function TKMSelectableEdit.KeyDown(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := KeyEventHandled(Key, Shift);
  if inherited KeyDown(Key, Shift) or ReadOnly then Exit;

  //Allow some keys while blocking input
  if BlockInput and not ((Key in [VK_LEFT, VK_RIGHT, VK_HOME, VK_END]) or ((ssCtrl in Shift) and (Key in [Ord('A'), Ord('C')]))) then Exit;

  //Clipboard operations
  if (Shift = [ssCtrl]) and (Key <> VK_CONTROL) then
    case Key of
      Ord('A'): begin
                  SelectionStart := 0;
                  SelectionEnd := Length(fText);
                end;
      Ord('C'): if HasSelection then
                  Clipboard.AsText := GetSelectedText;
      Ord('X'): if HasSelection then
                begin
                  Clipboard.AsText := GetSelectedText;
                  DeleteSelectedText;
                end;
      Ord('V'): begin
                  if HasSelection then
                  begin
                    Delete(fText, fSelectionStart+1, fSelectionEnd-fSelectionStart);
                    Insert(Clipboard.AsText, fText, fSelectionStart + 1);
                    ValidateText;
                    if CursorPos = fSelectionStart then
                      CursorPos := CursorPos + Length(Clipboard.AsText)
                    else if CursorPos = fSelectionEnd then
                      CursorPos := CursorPos + Length(Clipboard.AsText) - (fSelectionEnd-fSelectionStart);
                    ResetSelection;
                  end else begin
                    Insert(Clipboard.AsText, fText, CursorPos + 1);
                    ValidateText;
                    CursorPos := CursorPos + Length(Clipboard.AsText);
                  end;
                end;
    end;

  case Key of
    VK_BACK:    if HasSelection then
                  DeleteSelectedText
                else begin
                  Delete(fText, CursorPos, 1);
                  CursorPos := CursorPos-1;
                end;
    VK_DELETE:  if HasSelection then
                  DeleteSelectedText
                else
                  Delete(fText, CursorPos+1, 1);
  end;

  if (Shift = [ssShift]) and (Key <> VK_SHIFT) then
    case Key of
      VK_LEFT:    begin
                    if HasSelection then
                    begin
                      if CursorPos = SelectionStart then
                        SelectionStart := SelectionStart-1
                      else if CursorPos = SelectionEnd then
                        SelectionEnd := SelectionEnd-1;
                    end else begin
                      SelectionStart := CursorPos-1;
                      SelectionEnd := CursorPos;
                    end;
                    CursorPos := CursorPos-1;
                  end;
      VK_RIGHT:   begin
                    if HasSelection then
                    begin
                      if CursorPos = SelectionStart then
                        SelectionStart := SelectionStart+1
                      else if CursorPos = SelectionEnd then
                        SelectionEnd := SelectionEnd+1;
                    end else begin
                      SelectionStart := CursorPos;
                      SelectionEnd := CursorPos+1;
                    end;
                    CursorPos := CursorPos+1;
                  end;
      VK_HOME:    begin
                    if HasSelection then
                    begin
                      if SelectionEnd = CursorPos then
                        SelectionEnd := SelectionStart;
                    end else
                      SelectionEnd := CursorPos;
                    SelectionStart := 0;
                    CursorPos := 0;
                  end;
      VK_END:     begin
                    if HasSelection then
                    begin
                      if SelectionStart = CursorPos then
                        SelectionStart := SelectionEnd;
                    end else
                      SelectionStart := CursorPos;
                    SelectionEnd := Length(fText);
                    CursorPos := Length(fText);
                  end;
    end
  else
    case Key of
      VK_LEFT:    begin CursorPos := CursorPos-1; ResetSelection; end;
      VK_RIGHT:   begin CursorPos := CursorPos+1; ResetSelection; end;
      VK_HOME:    begin CursorPos := 0; ResetSelection; end;
      VK_END:     begin CursorPos := Length(fText); ResetSelection; end;
    end;
end;


procedure TKMSelectableEdit.KeyPress(Key: Char);
begin
  if ReadOnly or BlockInput then Exit;

  if HasSelection and IsCharValid(Key) then
    DeleteSelectedText
  else
    if Length(fText) >= GetMaxLength then Exit;

  Insert(Key, fText, CursorPos + 1);
  CursorPos := CursorPos + 1; //Before ValidateText so it moves the cursor back if the new char was invalid
  ValidateText;
end;


function TKMSelectableEdit.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := KeyEventHandled(Key, Shift);
  if inherited KeyUp(Key, Shift) or ReadOnly then Exit;

  if Assigned(OnChange) then OnChange(Self);
end;


procedure TKMSelectableEdit.MouseDown(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if ReadOnly then Exit;
  inherited;
  // Update Focus now, because we need to focus on MouseDown, not on MouseUp as by default for all controls
  MasterParent.fMasterControl.UpdateFocus(Self);

  CursorPos := GetCursorPosAt(X);
  ResetSelection;
  fSelectionInitialCursorPos := CursorPos;
end;


procedure TKMSelectableEdit.MouseMove(X, Y: Integer; Shift: TShiftState);
var
  CurCursorPos: Integer;
begin
  if ReadOnly then Exit;
  inherited;
  if ssLeft in Shift then
  begin
    CurCursorPos := GetCursorPosAt(X);
    // To rotate line to left while selecting
    if (X-SelfAbsLeft-4 < 0) and (fLeftIndex > 0) then
      CurCursorPos := CurCursorPos - 1;

    if fSelectionInitialCursorPos <> -1 then
    begin
      SelectionStart := min(CurCursorPos, fSelectionInitialCursorPos);
      SelectionEnd := max(CurCursorPos, fSelectionInitialCursorPos);
    end;
    CursorPos := CurCursorPos;
  end;
end;


procedure TKMSelectableEdit.MouseUp(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if ReadOnly then Exit;
  inherited;
  fSelectionInitialCursorPos := -1;
end;


procedure TKMSelectableEdit.PaintSelection;
var
  BeforeSelectionText, SelectionText: UnicodeString;
  BeforeSelectionW, SelectionW: Integer;
begin
  if HasSelection then
  begin
    BeforeSelectionText := Copy(fText, fLeftIndex+1, max(fSelectionStart, fLeftIndex) - fLeftIndex);
    SelectionText := Copy(fText, max(fSelectionStart, fLeftIndex)+1, fSelectionEnd - max(fSelectionStart, fLeftIndex));

    BeforeSelectionW := gRes.Fonts[fFont].GetTextSize(BeforeSelectionText).X;
    SelectionW := gRes.Fonts[fFont].GetTextSize(SelectionText).X;

    TKMRenderUI.WriteShape(SelfAbsLeft+4+BeforeSelectionW, AbsTop+3, min(SelectionW, Width-8), Height-6, clTextSelection);
  end;
end;


procedure TKMSelectableEdit.ControlMouseDown(Sender: TObject; Shift: TShiftState);
begin
  inherited;
  if (Sender <> Self) then
    ResetSelection;
end;


procedure TKMSelectableEdit.FocusChanged(aFocused: Boolean);
begin
  inherited;
  if not aFocused then
    ResetSelection;
end;


{ TKMEdit }
constructor TKMEdit.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aSelectable: Boolean = True);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aFont, aSelectable);
  fAllowedChars := acText; //Set to the widest by default
  MaxLen := 256; //Default max length to prevent chat spam
end;


function TKMEdit.GetMaxLength: Word;
begin
  Result := MaxLen;
end;


function TKMEdit.GetRText: UnicodeString;
begin
  if Masked then
    Result := StringOfChar('*', Length(fText))
  else
    Result := fText;
  Result := Copy(Result, fLeftIndex+1, Length(Result));
end;


function TKMEdit.HitTest(X, Y: Integer; aIncludeDisabled: Boolean = False): Boolean;
begin
  //When control is read-only we don't want to recieve Focus event
  Result := inherited HitTest(X,Y) and not ReadOnly;
end;


procedure TKMEdit.SetText(const aText: UnicodeString);
begin
  fText := aText;
  ValidateText; //Validate first since it could change fText
  CursorPos := Math.Min(CursorPos, Length(fText));
  //Setting the text should place cursor to the end
  fLeftIndex := 0;
  SetCursorPos(Length(Text));
end;


function TKMEdit.IsCharValid(aChar: WideChar): Boolean;
begin
  Result := IsCharAllowed(aChar, fAllowedChars);
end;


//Validates fText basing on predefined sets of allowed or disallowed chars
//It iterates from end to start of a string - deletes chars and moves cursor appropriately
procedure TKMEdit.ValidateText;
var I: Integer;
begin
  //Parse whole text incase user placed it from clipboard
  //Validate contents
  for I := Length(fText) downto 1 do
    if not IsCharValid(fText[I]) then
    begin
      Delete(fText, I, 1);
      if CursorPos >= I then //Keep cursor in place
        CursorPos := CursorPos - 1;
    end;

  //Validate length
  if Length(fText) > MaxLen then
    fText := Copy(fText, 0, MaxLen);
end;


//Key events which have no effect should not be handled (allows scrolling while chat window open with no text entered)
function TKMEdit.KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := True;

  //Don't include backspace/delete because edits should always handle those. Otherwise when you
  //press backspace repeatedly to remove all characters it will apply other shortcuts like
  //resetting the zoom if you press it once too many times.
  case Key of
    VK_UP,
    VK_DOWN,
    VK_LEFT,
    VK_RIGHT,
    VK_HOME,
    VK_END: Result := (fText <> ''); //These keys have no effect when text is blank
  end;

  //We want these keys to be ignored by TKMEdit
  if Key in [VK_F1..VK_F12, VK_ESCAPE, VK_RETURN, VK_TAB] then Result := False;

  //Ctrl can be used as an escape character, e.g. CTRL+B places beacon while chat is open
  if ssCtrl in Shift then Result := (Key in [Ord('A'), Ord('C'), Ord('X'), Ord('V')]);

  // If key is ignored, then check if can still handle it (check via OnIsKeyEventHandled)
  if not Result and Assigned(OnIsKeyEventHandled) then
    Result := OnIsKeyEventHandled(Self, Key);

end;


procedure TKMEdit.Paint;
var
  Col: TColor4;
  RText: UnicodeString;
  OffX: Integer;
begin
  inherited;

  if DrawOutline then
  begin
    TKMRenderUI.WriteShape(AbsLeft-1, AbsTop-1, Width+2, Height+2, $00000000, OutlineColor);
    TKMRenderUI.WriteShape(AbsLeft-2, AbsTop-2, Width+4, Height+4, $00000000, OutlineColor);
  end;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height);
  if fEnabled then Col:=$FFFFFFFF else Col:=$FF888888;

  if Masked then
    RText := StringOfChar('*', Length(fText))
  else
    RText := fText;
  RText := Copy(fText, fLeftIndex+1, Length(fText)); //Remove characters to the left of fLeftIndex

  PaintSelection;

  TKMRenderUI.WriteText(AbsLeft+4, AbsTop+3, Width-8, RText, fFont, taLeft, Col, not ShowColors, True); //Characters that do not fit are trimmed

  //Render text cursor
  if (csFocus in State) and ((TimeGet div 500) mod 2 = 0) then
  begin
    SetLength(RText, CursorPos - fLeftIndex);
    OffX := AbsLeft + 2 + gRes.Fonts[fFont].GetTextSize(RText, True).X;
    TKMRenderUI.WriteShape(OffX, AbsTop+2, 3, Height-4, Col, $FF000000);
  end;
end;


{ TKMCheckBox }
constructor TKMCheckBox.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; const aCaption: UnicodeString; aFont: TKMFont);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont     := aFont;
  fCaption  := aCaption;
  LineWidth := 1;
  LineColor := clChkboxOutline;
end;


procedure TKMCheckBox.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  if (csDown in State) and (Button = mbLeft) then
    fChecked := not fChecked;
  inherited; //There are OnMouseUp and OnClick events there
end;


//We can replace it with something better later on. For now [x] fits just fine
//Might need additional graphics to be added to gui.rx
//Some kind of box with an outline, darkened background and shadow maybe, similar to other controls.
procedure TKMCheckBox.Paint;
var Col: TColor4; CheckSize: Integer;
begin
  inherited;
  if fEnabled then Col := icWhite else Col := $FF888888;

  CheckSize := gRes.Fonts[fFont].GetTextSize('x').Y + 1;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, CheckSize - 4, CheckSize-4, 1, 0.3);

  if DrawOutline then
    TKMRenderUI.WriteOutline(AbsLeft, AbsTop, CheckSize - 4, CheckSize - 4, LineWidth, LineColor);

  if fChecked then
    TKMRenderUI.WriteText(AbsLeft + (CheckSize-4) div 2, AbsTop - 1, 0, 'x', fFont, taCenter, Col);

  TKMRenderUI.WriteText(AbsLeft + CheckSize, AbsTop, Width - Height, fCaption, fFont, taLeft, Col);
end;


{ TKMRadioGroup }
constructor TKMRadioGroup.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont := aFont;
  fItemIndex := -1;
  LineWidth := 1;
  LineColor := clChkboxOutline;
end;


procedure TKMRadioGroup.Add(aText: UnicodeString; aEnabled: Boolean);
begin
  if fCount >= Length(fItems) then
    SetLength(fItems, fCount + 8);

  fItems[fCount].Text := aText;
  fItems[fCount].Enabled := aEnabled;

  Inc(fCount);
end;


procedure TKMRadioGroup.Clear;
begin
  fCount := 0;
end;


procedure TKMRadioGroup.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  NewIndex: Integer;
begin
  if (csDown in State) and (Button = mbLeft) then
  begin
    NewIndex := EnsureRange((Y-AbsTop) div Round(Height/Count), 0, Count - 1); //Clicking at wrong place can select invalid ID
    if (NewIndex <> fItemIndex) and (fItems[NewIndex].Enabled) then
    begin
      fItemIndex := NewIndex;
      if Assigned(fOnChange) then
      begin
        fOnChange(Self);
        Exit; //Don't generate OnClick after OnChanged event (esp. when reloading Game on local change)
      end;
    end;
  end;

  inherited; //There are OnMouseUp and OnClick events there
end;


//We can replace it with something better later on. For now [x] fits just fine
//Might need additional graphics to be added to gui.rx
//Some kind of box with an outline, darkened background and shadow maybe, similar to other controls.
procedure TKMRadioGroup.Paint;
const
  FntCol: array [Boolean] of TColor4 = ($FF888888, $FFFFFFFF);
var
  LineHeight, CheckSize: Integer;
  I: Integer;
begin
  inherited;
  if Count = 0 then Exit; //Avoid dividing by zero

  LineHeight := Round(fHeight / Count);
  CheckSize := gRes.Fonts[fFont].GetTextSize('x').Y + 1;

  for I := 0 to Count - 1 do
  begin
    TKMRenderUI.WriteBevel(AbsLeft, AbsTop + I * LineHeight, CheckSize-4, CheckSize-4, 1, 0.3);
    if DrawChkboxOutline then
      TKMRenderUI.WriteOutline(AbsLeft, AbsTop + I * LineHeight, CheckSize-4, CheckSize-4, LineWidth, LineColor);

    if fItemIndex = I then
      TKMRenderUI.WriteText(AbsLeft+(CheckSize-4)div 2, AbsTop + I * LineHeight - 1, 0, 'x', fFont, taCenter, FntCol[fEnabled and fItems[I].Enabled]);

    // Caption
    TKMRenderUI.WriteText(AbsLeft+CheckSize, AbsTop + I * LineHeight, Width-LineHeight, fItems[I].Text, fFont, taLeft, FntCol[fEnabled and fItems[I].Enabled]);
  end;
end;


{ TKMPercentBar }
constructor TKMPercentBar.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont=fnt_Mini);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont := aFont;
  FontColor := $FFFFFFFF;
  fTextAlign := taCenter;
end;


procedure TKMPercentBar.SetCaptions(const aCaptionLeft, aCaption, aCaptionRight: UnicodeString);
begin
  CaptionLeft := aCaptionLeft;
  Caption := aCaption;
  CaptionRight := aCaptionRight;
end;


procedure TKMPercentBar.SetPosition(aValue: Single);
begin
  fPosition := EnsureRange(aValue, 0, 1);
end;


procedure TKMPercentBar.SetSeam(aValue: Single);
begin
  fSeam := EnsureRange(aValue, 0, 1);
end;


procedure TKMPercentBar.Paint;
var
  CaptionSize: TKMPoint;
begin
  inherited;

  TKMRenderUI.WritePercentBar(AbsLeft, AbsTop, Width, Height, fPosition, fSeam);

  //Now draw text over the bar, if it is required
  if Caption <> '' then
  begin
    //Shadow
    TKMRenderUI.WriteText(AbsLeft + 2, (AbsTop + Height div 2)+TextYOffset-4,
                          Width-4, Caption, fFont, fTextAlign, $FF000000);
    //Text
    TKMRenderUI.WriteText(AbsLeft + 1, (AbsTop + Height div 2)+TextYOffset-5,
                          Width-4, Caption, fFont, fTextAlign, FontColor);
  end;

  if (CaptionLeft <> '') or (CaptionRight <> '') then
    CaptionSize := gRes.Fonts[fFont].GetTextSize(Caption);

  if CaptionLeft <> '' then
  begin
    //Shadow
    TKMRenderUI.WriteText(AbsLeft + 2, (AbsTop + Height div 2)+TextYOffset-4,
                         (Width-4 - CaptionSize.X) div 2, CaptionLeft, fFont, taRight, $FF000000);
    //Text
    TKMRenderUI.WriteText(AbsLeft + 1, (AbsTop + Height div 2)+TextYOffset-5,
                         (Width-4 - CaptionSize.X) div 2, CaptionLeft, fFont, taRight, FontColor);
  end;

  if CaptionRight <> '' then
  begin
    //Shadow
    TKMRenderUI.WriteText(AbsLeft + 2 + ((Width-4 + CaptionSize.X) div 2), (AbsTop + Height div 2)+TextYOffset-4,
                         (Width-4 - CaptionSize.X) div 2, CaptionRight, fFont, taLeft, $FF000000);
    //Text
    TKMRenderUI.WriteText(AbsLeft + 1 + ((Width-4 + CaptionSize.X) div 2), (AbsTop + Height div 2)+TextYOffset-5,
                         (Width-4 - CaptionSize.X) div 2, CaptionRight, fFont, taLeft, FontColor);
  end;

end;


{ TKMWaresRow }
constructor TKMWaresRow.Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer);
begin
  Create(aParent, aLeft, aTop, aWidth, False);
end;


constructor TKMWaresRow.Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aClickable: Boolean);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, WARE_ROW_HEIGHT, 0);
  Clickable := aClickable;
  HideHighlight := not aClickable;
end;


procedure TKMWaresRow.Paint;
var
  I: Integer;
begin
  inherited;
  TKMRenderUI.WriteText(AbsLeft + 4, AbsTop + 3, Width-8, Caption, fnt_Game, taLeft, $FFE0E0E0);
  //Render in reverse order so the rightmost resource is on top (otherwise lighting looks wrong)
  if WareCntAsNumber then
  begin
    TKMRenderUI.WriteText(AbsLeft + Width - 18 - 70 + 24, AbsTop + 3, 22, IntToStr(WareCount), fnt_Game, taRight, $FFE0E0E0);
    TKMRenderUI.WritePicture(AbsLeft + Width - 18, AbsTop + 3, 14, 14, [], RX, TexID);
  end else
    for I := WareCount - 1 downto 0 do
      TKMRenderUI.WritePicture(AbsLeft + Width - 18 - I * 14, AbsTop + 3, 14, 14, [], RX, TexID);
end;


{ TKMNumericEdit }
constructor TKMNumericEdit.Create(aParent: TKMPanel; aLeft, aTop, aValueMin, aValueMax: Integer; aFont: TKMFont = fnt_Grey; aSelectable: Boolean = True);
var
  W: Word;
begin
  // Text width + padding + buttons
  W := Max(gRes.Fonts[fnt_Grey].GetTextSize(IntToStr(aValueMax)).X, gRes.Fonts[fnt_Grey].GetTextSize(IntToStr(aValueMin)).X) + 10 + 20 + 20;

  inherited Create(aParent, aLeft, aTop, W, 20, aFont, aSelectable);

  ReadOnly := False;

  ValueMin := aValueMin;
  ValueMax := aValueMax;
  Value := 0;

  fButtonDec := TKMButton.Create(aParent, aLeft,           aTop, 20, 20, '-', bsGame);
  fButtonInc := TKMButton.Create(aParent, aLeft + W - 20,  aTop, 20, 20, '+', bsGame);
  fButtonInc.CapOffsetY := 1;
  fButtonDec.OnClickShift := ButtonClick;
  fButtonInc.OnClickShift := ButtonClick;
  fButtonDec.OnMouseWheel := MouseWheel;
  fButtonInc.OnMouseWheel := MouseWheel;
  fButtonDec.OnClickHold := ClickHold;
  fButtonInc.OnClickHold := ClickHold;
end;


procedure TKMNumericEdit.ClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
var
  Amt: Integer;
begin
  inherited;
  aHandled := True;

  Amt := GetMultiplicator(Button);

  if Sender = fButtonDec then
    Value := Value - Amt
  else
  if Sender = fButtonInc then
    Value := Value + Amt;

  if (Amt <> 0) and Assigned(OnChange) then
    OnChange(Self);
end;


function TKMNumericEdit.KeyDown(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := KeyEventHandled(Key, Shift);
  inherited KeyDown(Key, Shift);

  case Key of
    VK_UP:      SetValueNCheckRange(Int64(Value) + 1 + 9*Byte(ssShift in Shift));
    VK_DOWN:    SetValueNCheckRange(Int64(Value) - 1 - 9*Byte(ssShift in Shift));
  end;
end;


function TKMNumericEdit.KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := True;

  //Don't include backspace/delete because edits should always handle those. Otherwise when you
  //press backspace repeatedly to remove all characters it will apply other shortcuts like
  //resetting the zoom if you press it once too many times.
  case Key of
    VK_LEFT,
    VK_RIGHT,
    VK_HOME,
    VK_END: Result := (fText <> ''); //These keys have no effect when text is blank
  end;

  //We want these keys to be ignored by TKMNumericEdit
  if Key in [VK_F1..VK_F12, VK_ESCAPE, VK_RETURN, VK_TAB] then Result := False;

  //Ctrl can be used as an escape character, e.g. CTRL+B places beacon while chat is open
  if ssCtrl in Shift then
    Result := (Key in [Ord('A'), Ord('C'), Ord('X'), Ord('V')]);
end;


function TKMNumericEdit.GetMaxLength: Word;
var
  MinValue: Integer;
begin
  if ValueMin = Low(Integer) then
    MinValue := ValueMin + 1  // to prevent integer overflow, when take Abs(MinValue);
  else
    MinValue := ValueMin;

  if (Max(Abs(ValueMax), Abs(MinValue)) <> 0) then
    Result := Trunc(Max(Log10(Abs(ValueMax)) + Byte(ValueMax < 0), Log10(Abs(MinValue)) + Byte(MinValue < 0))) + 1
  else
    Result := 1;
end;


procedure TKMNumericEdit.MouseWheel(Sender: TObject; WheelDelta: Integer);
begin
  inherited;

  if WheelDelta > 0 then
    SetValueNCheckRange(Int64(Value) + 1 + 9*Byte(GetKeyState(VK_SHIFT) < 0));
  if WheelDelta < 0 then
    SetValueNCheckRange(Int64(Value) - 1 - 9*Byte(GetKeyState(VK_SHIFT) < 0));

  Focus;

  if Assigned(OnChange) then
    OnChange(Self);
end;


procedure TKMNumericEdit.ButtonClick(Sender: TObject; Shift: TShiftState);
begin
  if Sender = fButtonDec then
    SetValueNCheckRange(Int64(Value) - GetMultiplicator(Shift))
  else
  if Sender = fButtonInc then
    SetValueNCheckRange(Int64(Value) + GetMultiplicator(Shift))
  else
    Exit;

  Focus;

  if Assigned(OnChange) then
    OnChange(Self);
end;


procedure TKMNumericEdit.SetSharedHint(const aHint: UnicodeString);
begin
  Hint := aHint;
  fButtonInc.Hint := aHint;
  fButtonDec.Hint := aHint;
end;


procedure TKMNumericEdit.SetTop(aValue: Integer);
begin
  inherited;

  fButtonDec.Top := Top;
  fButtonInc.Top := Top;
end;


procedure TKMNumericEdit.SetLeft(aValue: Integer);
begin
  inherited;

  fButtonDec.Left := Left;
  fButtonInc.Top := Left + Width - 20;
end;


procedure TKMNumericEdit.SetEnabled(aValue: Boolean);
begin
  inherited;
  fButtonDec.Enabled := fEnabled;
  fButtonInc.Enabled := fEnabled;
end;


procedure TKMNumericEdit.SetVisible(aValue: Boolean);
begin
  inherited;
  fButtonDec.Visible := fVisible;
  fButtonInc.Visible := fVisible;
end;


function TKMNumericEdit.GetSelfAbsLeft: Integer;
begin
  Result := AbsLeft + 20;
end;


function TKMNumericEdit.GetSelfWidth: Integer;
begin
  Result := fWidth - 40;
end;


function TKMNumericEdit.IsCharValid(Key: WideChar): Boolean;
begin
  Result := SysUtils.CharInSet(Key, ['0'..'9']);
end;


procedure TKMNumericEdit.SetValueNCheckRange(aValue: Int64);
begin
  SetValue(EnsureRange(aValue, Low(Integer), High(Integer)));
end;


procedure TKMNumericEdit.SetValue(aValue: Integer);
begin
  fValue := EnsureRange(aValue, ValueMin, ValueMax);
  fText := IntToStr(fValue);

  //External Value assignment should not generate OnChange event
end;


procedure TKMNumericEdit.ValidateText;
var
  I: Integer;
  AllowedChars: TSetOfAnsiChar;
  OnlyMinus, IsEmpty: Boolean;
begin
  IsEmpty := (fText = #8); // When deleting text with Backspace last character is still in string - backspace character (#8)

  AllowedChars := ['0'..'9'];
  //Validate contents
  for I := Length(fText) downto 1 do
  begin
    if I = 1 then Include(AllowedChars, '-');

    if not KromUtils.CharInSet(fText[I], AllowedChars) then
    begin
      Delete(fText, I, 1);
      if CursorPos >= I then //Keep cursor in place
        CursorPos := CursorPos - 1;
    end;
  end;

  OnlyMinus := (fText = '-');

  if (fText = '') or OnlyMinus or IsEmpty then
    Value := 0
  else
    SetValueNCheckRange(StrToInt64(fText));

  if OnlyMinus then fText := '-'; //Set text back to '-' while still editing.
  if IsEmpty then fText := ''; //Set text back to '' while still editing.

  CursorPos := Min(CursorPos, Length(fText)); //In case we had leading zeros in fText string

  if Assigned(OnChange) then
    OnChange(Self);
end;


procedure TKMNumericEdit.Paint;
var
  Col: TColor4;
  RText: UnicodeString;
  OffX: Integer;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft + 20, AbsTop, Width - 40, Height);
  if fEnabled then Col:=$FFFFFFFF else Col:=$FF888888;

  RText := Copy(fText, fLeftIndex+1, Length(fText)); //Remove characters to the left of fLeftIndex

  PaintSelection;

  TKMRenderUI.WriteText(AbsLeft+24, AbsTop+3, 0, fText, fFont, taLeft, Col); //Characters that do not fit are trimmed

  //Render text cursor
  if (csFocus in State) and ((TimeGet div 500) mod 2 = 0) then
  begin
    SetLength(RText, CursorPos - fLeftIndex);
    OffX := AbsLeft + 22 + gRes.Fonts[fFont].GetTextSize(RText).X;
    TKMRenderUI.WriteShape(OffX, AbsTop+2, 3, Height-4, Col, $FF000000);
  end;
end;


procedure TKMNumericEdit.CheckValueOnUnfocus;
begin
  if (fText = '-') or (fText = '') then //after unfocus, if only '-' is in string, set value to 0
    Value := 0;
end;


procedure TKMNumericEdit.FocusChanged(aFocused: Boolean);
begin
  inherited;
  if not aFocused then
    CheckValueOnUnfocus;
end;


procedure TKMNumericEdit.ControlMouseDown(Sender: TObject; Shift: TShiftState);
begin
  inherited;
  if (Sender <> Self) then
    CheckValueOnUnfocus;
end;


{ TKMWareOrderRow }
constructor TKMWareOrderRow.Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aOrderCntMax: Integer = MAX_WARES_IN_HOUSE; aOrderCntMin: Integer = 0);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, WARE_ROW_HEIGHT);

  fWaresRow := TKMWaresRow.Create(aParent, aLeft + 68, aTop, aWidth - 68);

  OrderCntMin := aOrderCntMin;
  OrderCntMax := aOrderCntMax;

  fOrderRem := TKMButton.Create(aParent, aLeft,   0, 20, fHeight - 2, '-', bsGame);
  fOrderLab := TKMLabel.Create (aParent, aLeft + 33,  0, '', fnt_Grey, taCenter);
  fOrderAdd := TKMButton.Create(aParent, aLeft + 46,  0, 20, fHeight - 2, '+', bsGame);
  fOrderAdd.CapOffsetY := 1;

  fOrderRem.OnClickShift := ButtonClick;
  fOrderAdd.OnClickShift := ButtonClick;
  fOrderRem.OnMouseWheel := MouseWheel;
  fOrderAdd.OnMouseWheel := MouseWheel;
  fWaresRow.OnMouseWheel := MouseWheel;
  fOrderRem.OnClickHold := ClickHold;
  fOrderAdd.OnClickHold := ClickHold;
end;


procedure TKMWareOrderRow.ButtonClick(Sender: TObject; Shift: TShiftState);
var
  Amt: Integer;
begin
  Amt := GetMultiplicator(Shift);
  if Sender = fOrderRem then
    Amt := -Amt;

  if Amt = 0 then Exit;

  OrderCount := fOrderCount + Amt;
  Focus;

  if Assigned(OnChange) then
    OnChange(Self, Amt);
end;


procedure TKMWareOrderRow.MouseWheel(Sender: TObject; WheelDelta: Integer);
const
  ORDER_WHEEL_AMOUNT = 5; // Amounts for placing orders
var
  Amt: Integer;
begin
  inherited;

  Amt := ORDER_WHEEL_AMOUNT * Sign(WheelDelta);
  if GetKeyState(VK_SHIFT) < 0 then
    Amt := Amt * 10;

  OrderCount := fOrderCount + Amt;
  Focus;

  if Assigned(OnChange) then
    OnChange(Self, Amt);
end;


procedure TKMWareOrderRow.ClickHold(Sender: TObject; Button: TMouseButton; var aHandled: Boolean);
var
  Amt: Integer;
begin
  inherited;
  aHandled := True;

  Amt := GetMultiplicator(Button);

  if Sender = fOrderRem then
    Amt := -Amt;

  if Amt = 0 then Exit;

  OrderCount := fOrderCount + Amt;

  if (Amt <> 0) and Assigned(OnChange) then
    OnChange(Self, Amt);
end;


procedure TKMWareOrderRow.SetOrderCount(aValue: Integer);
begin
  fOrderCount := EnsureRange(aValue, OrderCntMin, OrderCntMax);
end;


procedure TKMWareOrderRow.SetOrderRemHint(aValue: UnicodeString);
begin
  fOrderRem.Hint := aValue;
end;


procedure TKMWareOrderRow.SetOrderAddHint(aValue: UnicodeString);
begin
  fOrderAdd.Hint := aValue;
end;


procedure TKMWareOrderRow.SetTop(aValue: Integer);
begin
  inherited;
  fWaresRow.Top := aValue;
end;


//Copy property to buttons
procedure TKMWareOrderRow.SetEnabled(aValue: Boolean);
begin
  inherited;
  fWaresRow.Enabled := fEnabled;
  fOrderRem.Enabled := fEnabled;
  fOrderLab.Enabled := fEnabled;
  fOrderAdd.Enabled := fEnabled;
end;


//Copy property to buttons. Otherwise they won't be rendered
procedure TKMWareOrderRow.SetVisible(aValue: Boolean);
begin
  inherited;
  fWaresRow.Visible := fVisible;
  fOrderRem.Visible := fVisible;
  fOrderLab.Visible := fVisible;
  fOrderAdd.Visible := fVisible;
end;


procedure TKMWareOrderRow.Paint;
begin
  inherited;

  fOrderRem.Top := Top + 1; //Use internal fTop instead of GetTop (which will return absolute value)
  fOrderLab.Top := Top + 4;
  fOrderAdd.Top := Top + 1;

  fOrderLab.Caption := IntToStr(OrderCount);
end;


{ TKMCostsRow }
procedure TKMCostsRow.Paint;
var
  I: Integer;
begin
  inherited;
  TKMRenderUI.WriteText(AbsLeft, AbsTop + 4, Width-20, Caption, fnt_Grey, taLeft, $FFFFFFFF);
  if Count > 0 then
  begin
    if TexID1 <> 0 then
      for I := 0 to Count - 1 do
        TKMRenderUI.WritePicture(AbsLeft+Width-19*(I+1), AbsTop, 20, fHeight, [], RX, TexID1);
  end else begin
    if TexID1 <> 0 then
      TKMRenderUI.WritePicture(AbsLeft+Width-40, AbsTop, 20, fHeight, [], RX, TexID1);
    if TexID2 <> 0 then
      TKMRenderUI.WritePicture(AbsLeft+Width-20, AbsTop, 20, fHeight, [], RX, TexID2);
  end;
end;


{ TKMTrackBar }
constructor TKMTrackBar.Create(aParent: TKMPanel; aLeft, aTop, aWidth: Integer; aMin, aMax: Word);
begin
  inherited Create(aParent, aLeft,aTop,aWidth,0);
  fMinValue := aMin;
  fMaxValue := aMax;
  fTrackHeight := 20;
  Position := (fMinValue + fMaxValue) div 2;
  Caption := '';
  ThumbWidth := gRes.Fonts[fFont].GetTextSize(IntToStr(MaxValue)).X + 24;

  Font := fnt_Metal;
  Step := 1;
end;


procedure TKMTrackBar.SetCaption(const aValue: UnicodeString);
begin
  fCaption := aValue;

  if Trim(fCaption) <> '' then
  begin
    fHeight := 20 + fTrackHeight;
    fTrackTop := 20;
  end
  else
  begin
    fHeight := fTrackHeight;
    fTrackTop := 0;
  end;
end;


procedure TKMTrackBar.SetPosition(aValue: Word);
begin
  fPosition := EnsureRange(aValue, MinValue, MaxValue);
  ThumbText := IntToStr(Position);
end;


procedure TKMTrackBar.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  MouseMove(X, Y, Shift);
end;


procedure TKMTrackBar.MouseMove(X,Y: Integer; Shift: TShiftState);
var
  NewPos: Integer;
begin
  inherited;

  NewPos := Position;
  if (ssLeft in Shift) and InRange(Y - AbsTop - fTrackTop, 0, fTrackHeight) then
    NewPos := EnsureRange(fMinValue + Round(((X-AbsLeft-ThumbWidth div 2) / (Width - ThumbWidth - 4))*(fMaxValue - fMinValue)/Step)*Step, fMinValue, fMaxValue);

  if NewPos <> Position then
  begin
    Position := NewPos;

    if Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


procedure TKMTrackBar.Paint;
const //Text color for disabled and enabled control
  TextColor: array [Boolean] of TColor4 = ($FF888888, $FFFFFFFF);
var
  ThumbPos, ThumbHeight: Word;
begin
  inherited;

  if fCaption <> '' then
    TKMRenderUI.WriteText(AbsLeft, AbsTop, Width, fCaption, fFont, taLeft, TextColor[fEnabled]);

  TKMRenderUI.WriteBevel(AbsLeft+2,AbsTop+fTrackTop+2,Width-4,fTrackHeight-4);
  ThumbPos := Round(Mix (0, Width - ThumbWidth - 4, 1-(Position-fMinValue) / (fMaxValue - fMinValue)));

  ThumbHeight := gRes.Sprites[rxGui].RXData.Size[132].Y;

  TKMRenderUI.WritePicture(AbsLeft + ThumbPos + 2, AbsTop+fTrackTop, ThumbWidth, ThumbHeight, [anLeft,anRight], rxGui, 132);
  TKMRenderUI.WriteText(AbsLeft + ThumbPos + ThumbWidth div 2 + 2, AbsTop+fTrackTop+3, 0, ThumbText, fnt_Metal, taCenter, TextColor[fEnabled]);
end;


{ TKMScrollBar }
constructor TKMScrollBar.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aScrollAxis: TScrollAxis; aStyle: TKMButtonStyle);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  BackAlpha := 0.5;
  EdgeAlpha := 0.75;
  fScrollAxis := aScrollAxis;
  fMinValue := 0;
  fMaxValue := 10;
  fPosition := 0;
  fStyle    := aStyle;

  if aScrollAxis = sa_Vertical then
  begin
    fScrollDec := TKMButton.Create(Self, 0, 0, aWidth, aWidth, 591, rxGui, aStyle);
    fScrollInc := TKMButton.Create(Self, 0, aHeight-aWidth, aWidth, aWidth, 590, rxGui, aStyle);
    fScrollDec.Anchors := [anLeft, anTop, anRight];
    fScrollInc.Anchors := [anLeft, anRight, anBottom];
  end;
  if aScrollAxis = sa_Horizontal then
  begin
    fScrollDec := TKMButton.Create(Self, 0, 0, aHeight, aHeight, 2, rxGui, aStyle);
    fScrollInc := TKMButton.Create(Self, aWidth-aHeight, 0, aHeight, aHeight, 3, rxGui, aStyle);
    fScrollDec.Anchors := [anLeft, anTop, anBottom];
    fScrollInc.Anchors := [anTop, anRight, anBottom];
  end;
  fScrollDec.OnClick := DecPosition;
  fScrollDec.OnMouseWheel := MouseWheel;
  fScrollInc.OnClick := IncPosition;
  fScrollInc.OnMouseWheel := MouseWheel;
  UpdateThumbSize;
end;


procedure TKMScrollBar.SetHeight(aValue: Integer);
begin
  inherited;

  //Update Thumb size
  UpdateThumbSize;
end;


procedure TKMScrollBar.SetWidth(aValue: Integer);
begin
  inherited;

  //Update Thumb size
  UpdateThumbSize;
end;


procedure TKMScrollBar.SetEnabled(aValue: Boolean);
begin
  inherited;
  fScrollDec.Enabled := aValue;
  fScrollInc.Enabled := aValue;
end;


procedure TKMScrollBar.SetMinValue(Value: Integer);
begin
  fMinValue := Max(0, Value);
  Enabled := (fMaxValue > fMinValue);
  SetPosition(fPosition);
end;


procedure TKMScrollBar.SetMaxValue(Value: Integer);
begin
  fMaxValue := Max(0, Value);
  Enabled := (fMaxValue > fMinValue);
  SetPosition(fPosition);
end;


procedure TKMScrollBar.SetPosition(Value: Integer);
begin
  fPosition := EnsureRange(Value, fMinValue, fMaxValue);
  UpdateThumbPos;
end;


procedure TKMScrollBar.IncPosition(Sender: TObject);
begin
  SetPosition(fPosition + 1);

  if Assigned(fOnChange) then
    fOnChange(Self);
end;


procedure TKMScrollBar.DecPosition(Sender: TObject);
begin
  SetPosition(fPosition - 1);

  if Assigned(fOnChange) then
    fOnChange(Self);
end;


procedure TKMScrollBar.UpdateThumbPos;
begin
  fThumbPos := 0;

  if fMaxValue > fMinValue then
    case fScrollAxis of
      sa_Vertical:   fThumbPos := (fPosition-fMinValue)*(Height-Width*2-fThumbSize) div (fMaxValue-fMinValue);
      sa_Horizontal: fThumbPos := (fPosition-fMinValue)*(Width-Height*2-fThumbSize) div (fMaxValue-fMinValue);
    end
  else
    case fScrollAxis of
      sa_Vertical:   fThumbPos := Math.max((Height-Width*2-fThumbSize),0) div 2;
      sa_Horizontal: fThumbPos := Math.max((Width-Height*2-fThumbSize),0) div 2;
    end;
end;


procedure TKMScrollBar.UpdateThumbSize;
begin
  case fScrollAxis of
    sa_Vertical:   fThumbSize := Math.max(0, (Height-2*Width)) div 4;
    sa_Horizontal: fThumbSize := Math.max(0, (Width-2*Height)) div 4;
  end;

  //If size has changed, then Pos needs to be updated as well (depends on it)
  UpdateThumbPos;
end;


procedure TKMScrollBar.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  T: Integer;
begin
  inherited;

  fOffset := 0;
  case fScrollAxis of
    sa_Vertical:    begin
                      T := Y - AbsTop - Width - fThumbPos;
                      if InRange(T, 0, fThumbSize) then
                        fOffset := T - fThumbSize div 2;
                    end;
    sa_Horizontal:  begin
                      T := X - AbsLeft - Height - fThumbPos;
                      if InRange(T, 0, fThumbSize) then
                        fOffset := T - fThumbSize div 2;
                    end;
  end;

  MouseMove(X,Y,Shift); //Will change Position and call OnChange event
end;


procedure TKMScrollBar.MouseMove(X,Y: Integer; Shift: TShiftState);
var
  NewPos: Integer;
  T: Integer;
begin
  inherited;
  if not (ssLeft in Shift) then Exit;

  NewPos := fPosition;

  case fScrollAxis of
    sa_Vertical:
      begin
        T := Y - fOffset - AbsTop - Width;
        if InRange(T, 0, Height - Width * 2) then
          NewPos := Round(fMinValue+((T - fThumbSize / 2) / (Height-Width*2-fThumbSize)) * (fMaxValue - fMinValue) );
      end;

    sa_Horizontal:
      begin
        T := X - fOffset - AbsLeft - Height;
        if InRange(T, 0, Width - Height * 2) then
          NewPos := Round(fMinValue+((T - fThumbSize / 2) / (Width-Height*2-fThumbSize)) * (fMaxValue - fMinValue) );
      end;
  end;

  if NewPos <> fPosition then
  begin
    SetPosition(NewPos);
    if Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


procedure TKMScrollBar.MouseWheel(Sender: TObject; WheelDelta: Integer);
begin
  inherited;
  if WheelDelta < 0 then IncPosition(Self);
  if WheelDelta > 0 then DecPosition(Self);
end;


procedure TKMScrollBar.Paint;
var
  ButtonState: TKMButtonStateSet;
begin
  inherited;

  case fScrollAxis of
    sa_Vertical:   TKMRenderUI.WriteBevel(AbsLeft, AbsTop+Width, Width, Height - Width*2, EdgeAlpha, BackAlpha);
    sa_Horizontal: TKMRenderUI.WriteBevel(AbsLeft+Height, AbsTop, Width - Height*2, Height, EdgeAlpha, BackAlpha);
  end;

  if fMaxValue > fMinValue then
    ButtonState := []
  else
    ButtonState := [bsDisabled];

  if not (bsDisabled in ButtonState) then //Only show thumb when usable
    case fScrollAxis of
      sa_Vertical:   TKMRenderUI.Write3DButton(AbsLeft,AbsTop+Width+fThumbPos,Width,fThumbSize,rxGui,0,$FFFF00FF,ButtonState,fStyle);
      sa_Horizontal: TKMRenderUI.Write3DButton(AbsLeft+Height+fThumbPos,AbsTop,fThumbSize,Height,rxGui,0,$FFFF00FF,ButtonState,fStyle);
    end;
end;


{ TKMMemo }
constructor TKMMemo.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle; aSelectable: Boolean = True);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fItemHeight := 20;
  fItems := TStringList.Create;
  fFont := aFont;

  fScrollBar := TKMScrollBar.Create(aParent, aLeft+aWidth-20, aTop, 20, aHeight, sa_Vertical, aStyle);
  UpdateScrollBar; //Initialise the scrollbar
  fSelectable := aSelectable;
end;


destructor TKMMemo.Destroy;
begin
  fItems.Free;
  inherited;
end;


procedure TKMMemo.SetHeight(aValue: Integer);
begin
  inherited;
  fScrollBar.Height := fHeight;
  UpdateScrollBar; //Since height has changed
end;


procedure TKMMemo.SetWidth(aValue: Integer);
begin
  inherited;
  fScrollBar.Left := Left + Width - fScrollBar.Width;
  ReformatText; //Repositions the scroll bar as well
end;


//Copy property to scrollbar. Otherwise it won't be rendered
procedure TKMMemo.SetVisible(aValue: Boolean);
begin
  inherited;

  //Hide scrollbar and its buttons
  fScrollBar.Visible := fVisible and (fScrollBar.MaxValue <> fScrollBar.MinValue);
end;


function TKMMemo.GetTopIndex: smallint;
begin
  Result := fScrollBar.Position;
end;


procedure TKMMemo.SetTopIndex(aIndex: smallint);
begin
  fScrollBar.Position := aIndex;
end;


procedure TKMMemo.SetEnabled(aValue: Boolean);
begin
  inherited;
  fScrollBar.Enabled := aValue;
end;


procedure TKMMemo.SetTop(aValue: Integer);
begin
  inherited;
  fScrollBar.Top := Top;
end;


procedure TKMMemo.SetAutoWrap(const Value: boolean);
begin
  fAutoWrap := Value;
  ReformatText;
end;


procedure TKMListBox.SetItemHeight(const Value: byte);
begin
  fItemHeight := Value;
  UpdateScrollBar;
end;


function TKMMemo.GetText: UnicodeString;
begin
  Result := fText;
end;


procedure TKMMemo.SetText(const aText: UnicodeString);
begin
  fText := aText;
  ReformatText;
end;


procedure TKMMemo.ReformatText;
var
  newText: UnicodeString;
begin
  if fAutoWrap then
    newText := gRes.Fonts[fFont].WordWrap(fText, fWidth - fScrollBar.Width - 8, True, IndentAfterNL)
  else
    newText := fText;

  //KaM uses | for new line, fItems.Text:= uses standard eol to parse each item from the string
  fItems.Text := StringReplace(newText, '|', EolW, [rfReplaceAll]);
  UpdateScrollBar;
end;


function TKMMemo.GetVisibleRows: Integer;
begin
  Result := fHeight div fItemHeight;
end;


//fItems.Count or Height has changed
procedure TKMMemo.UpdateScrollBar;
var
  OldMax: Integer;
begin
  OldMax := fScrollBar.MaxValue;
  fScrollBar.MaxValue := fItems.Count - GetVisibleRows;
  fScrollBar.Visible := fVisible and (fScrollBar.MaxValue <> fScrollBar.MinValue);

  if fScrollDown then
  begin
    if OldMax-fScrollBar.Position <= 2 then //If they were near the bottom BEFORE updating, keep them at the bottom
      SetTopIndex(fItems.Count) //This puts it at the bottom because of the EnsureRange in SetTopIndex
  end
  else
    SetTopIndex(0);
end;


procedure TKMMemo.SetCursorPos(aPos: Integer);
begin
  fCursorPos := EnsureRange(aPos, 0, GetMaxCursorPos);
end;


function TKMMemo.GetSelectedText: UnicodeString;
begin
  Result := '';
  if HasSelection then
  begin
    // First remove EOL's to get correct positions in text
    Result := StringReplace(fItems.Text, EolW, '|', [rfReplaceAll]);
    // Get text with selected positions, cleaned of color markup
    Result := Copy(GetNoColorMarkupText(Result), fSelectionStart+1, fSelectionEnd - fSelectionStart);
    // Return EOL's back
    Result := StringReplace(Result, '|', EolW, [rfReplaceAll]);
  end;
end;


function TKMMemo.HasSelection: Boolean;
begin
  Result := (fSelectionStart <> -1) and (fSelectionEnd <> -1) and (fSelectionStart <> fSelectionEnd);
end;


procedure TKMMemo.ResetSelection;
begin
  fSelectionStart := -1;
  fSelectionEnd := -1;
  fSelectionInitialPos := -1;
end;


//We are using 2 systems for position: Linear (cumulative) and 'Point' (2D with column and row)
//Every system have Length(RowText)+1 positions in every line
//Convert Linear position into 2D position
function TKMMemo.LinearToPointPos(aPos: Integer): TKMPoint;
var I, Row, Column: Integer;
    RowText: UnicodeString;
    RowStartPos, RowEndPos: Integer;
begin
  Row := 0;
  Column := 0;
  for I := 0 to fItems.Count - 1 do
  begin
    RowText := GetNoColorMarkupText(fItems[I]);
    RowStartPos := PointToLinearPos(0, I);
    RowEndPos := RowStartPos + Length(RowText);
    if InRange(aPos, RowStartPos, RowEndPos) then
    begin
      Row := I;
      Column := aPos - RowStartPos;
      Break;
    end;
  end;
  Result := KMPoint(Column, Row);
end;


//We are using 2 systems for position: Linear (cumulative) and 'Point' (2D with column and row)
//Every system have Length(RowText)+1 positions in every line
//Convert 2D position into Linear position
function TKMMemo.PointToLinearPos(aColumn, aRow: Integer): Integer;
var I: Integer;
begin
  Result := 0;
  aRow := EnsureRange(aRow, 0, fItems.Count-1);
  for I := 0 to aRow-1 do
    Inc(Result, Length(GetNoColorMarkupText(fItems[I])) + 1); //+1 for special KaM new line symbol ('|')
  Inc(Result, EnsureRange(aColumn, 0, GetMaxPosInRow(aRow)));
end;


//Return position of Cursor in 2D of point X,Y on the screen
function TKMMemo.GetCharPosAt(X,Y: Integer): TKMPoint;
var Row, Column: Integer;
begin
  Row := 0;
  Column := 0;

  if fItems.Count > 0 then
  begin
    Row := (EnsureRange(Y-AbsTop-3, 0, fHeight-6) div fItemHeight) + TopIndex;
    Row := EnsureRange(Row, 0, fItems.Count-1);
    Column := gRes.Fonts[fFont].CharsThatFit(GetNoColorMarkupText(fItems[Row]), X-AbsLeft-4);
  end;
  Result := KMPoint(Column, Row);
end;


//Return position of Cursor in linear system of point X,Y on the screen
function TKMMemo.GetCursorPosAt(X,Y: Integer): Integer;
var CharPos: TKMPoint;
begin
  CharPos := GetCharPosAt(X, Y);
  Result := PointToLinearPos(CharPos.X, CharPos.Y);
end;


// Maximum possible position of Cursor
function TKMMemo.GetMaxCursorPos: Integer;
begin
  Result := Length(StringReplace(fItems.Text, EolW, '', [rfReplaceAll])) + EnsureRange(fItems.Count-1, 0, fItems.Count);
end;


// Minimum possible position of Cursor in its current Row
function TKMMemo.GetMinCursorPosInRow: Integer;
begin
  Result := GetMinPosInRow(LinearToPointPos(CursorPos).Y)
end;


// Maximum possible position of Cursor in its current Row
function TKMMemo.GetMaxCursorPosInRow: Integer;
begin
  Result := GetMaxPosInRow(LinearToPointPos(CursorPos).Y)
end;


// Minimum possible position of Cursor in the specified aRow
function TKMMemo.GetMinPosInRow(aRow: Integer): Integer;
begin
  if aRow = 0 then
    Result := 0
  else
    Result := GetMaxPosInRow(aRow - 1) + 1;
end;


// Maximum possible position of Cursor in the specified aRow
function TKMMemo.GetMaxPosInRow(aRow: Integer): Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to min(aRow, fItems.Count - 1) do
    Inc(Result, Length(GetNoColorMarkupText(fItems[I])) + 1);
  Result := EnsureRange(Result - 1, 0, Result);
end;


procedure TKMMemo.SetSelectionStart(aValue: Integer);
var MaxPos: Integer;
begin
  if fSelectable then
  begin
    MaxPos := GetMaxCursorPos;
    fSelectionStart := EnsureRange(aValue, 0, MaxPos);
  end;
end;


procedure TKMMemo.SetSelectionEnd(aValue: Integer);
var MaxPos: Integer;
begin
  if fSelectable then
  begin
    MaxPos := GetMaxCursorPos;
    fSelectionEnd := EnsureRange(aValue, 0, MaxPos);
  end;
end;


//Set selections with pair of value, using he fact, that fSelectionStart <= fSelectionEnd
procedure TKMMemo.SetSelections(aValue1, aValue2: Integer);
begin
  fSelectionStart := min(aValue1, aValue2);
  fSelectionEnd := max(aValue1, aValue2);
end;


//Update selection start/end due to change cursor position
procedure TKMMemo.UpdateSelection(aPrevCursorPos: Integer);
begin
  if HasSelection then
  begin
    if aPrevCursorPos = SelectionStart then
      SetSelections(CursorPos, SelectionEnd)
    else if aPrevCursorPos = SelectionEnd then
      SetSelections(SelectionStart, CursorPos);
  end else
    SetSelections(aPrevCursorPos, CursorPos);
end;


procedure TKMMemo.Add(const aItem: UnicodeString);
begin
  if fText <> '' then
    fText := fText + '|';

  fText := fText + aItem; //Append the new string

  SetText(fText); //Updates the text in fItems
  UpdateScrollBar; //Scroll down with each item that is added.
end;


procedure TKMMemo.Clear;
begin
  fText := '';
  fItems.Clear;
  ResetSelection;
  UpdateScrollBar;
end;


procedure TKMMemo.ScrollToBottom;
begin
  SetTopIndex(fItems.Count);
end;


//Key events which have no effect should not be handled (allows scrolling while chat window open with no text entered)
function TKMMemo.KeyEventHandled(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := True;

  //Don't include backspace/delete because edits should always handle those. Otherwise when you
  //press backspace repeatedly to remove all characters it will apply other shortcuts like
  //resetting the zoom if you press it once too many times.
  case Key of
    VK_UP,
    VK_DOWN,
    VK_LEFT,
    VK_RIGHT,
    VK_HOME,
    VK_END,
    VK_PRIOR,
    VK_NEXT: Result := (fText <> ''); //These keys have no effect when text is blank
  end;

  //We want these keys to be ignored by chat, so game shortcuts still work
  if Key in [VK_F1..VK_F12, VK_ESCAPE] then Result := False;

  //Ctrl can be used as an escape character, e.g. CTRL+B places beacon while chat is open
  if ssCtrl in Shift then Result := (Key in [Ord('A'), Ord('C'), Ord('X')]);
end;


function TKMMemo.KeyDown(Key: Word; Shift: TShiftState): Boolean;
  //Move cursor vertically (change cursor row)
  procedure MoveCursorVertically(aRowIncrement: Integer);
  var CursorPointPos: TKMPoint;
      NewCursorPosY: Integer;
      SrcLineText, DestLineText: UnicodeString;
  begin
    CursorPointPos := LinearToPointPos(CursorPos);
    NewCursorPosY := EnsureRange(CursorPointPos.Y + aRowIncrement, 0, fItems.Count-1);
    if NewCursorPosY <> CursorPointPos.Y then
    begin
      // Because we don't use monospaces fonts, then its better to find proper column, which depends of text width in px
      SrcLineText := GetNoColorMarkupText(Copy(fItems[CursorPointPos.Y], 1, CursorPointPos.X));
      DestLineText := GetNoColorMarkupText(fItems[NewCursorPosY]);
      //Use 'rounding' version of CharsThatFit to get more precise position
      CursorPointPos.X := gRes.Fonts[fFont].CharsThatFit(DestLineText, gRes.Fonts[fFont].GetTextSize(SrcLineText).X, True);
      CursorPos := PointToLinearPos(CursorPointPos.X, NewCursorPosY);
      // Update scroll position, if needed
      if TopIndex > NewCursorPosY then
        TopIndex := NewCursorPosY
      else if TopIndex < NewCursorPosY - GetVisibleRows + 1 then
        TopIndex := NewCursorPosY - GetVisibleRows + 1;
    end;
  end;

  procedure MoveCursorVerticallyNUpdateSelections(aRowIncrement: Integer);
  var OldCursorPos: Integer;
  begin
    OldCursorPos := CursorPos;
    MoveCursorVertically(aRowIncrement);
    UpdateSelection(OldCursorPos);
  end;

var OldCursorPos: Integer;
begin
  Result := KeyEventHandled(Key, Shift);
  if inherited KeyDown(Key, Shift) then Exit;

  //Clipboard operations
  if (Shift = [ssCtrl]) and (Key <> VK_CONTROL) then
    case Key of
      Ord('A'): SetSelections(0, GetMaxCursorPos);
      Ord('C'),
      Ord('X'): if HasSelection then
                  Clipboard.AsText := GetSelectedText;
    end;

  if (Shift = [ssShift]) and (Key <> VK_SHIFT) then
    case Key of
      VK_UP:    MoveCursorVerticallyNUpdateSelections(-1);
      VK_DOWN:  MoveCursorVerticallyNUpdateSelections(1);
      VK_PRIOR: MoveCursorVerticallyNUpdateSelections(-GetVisibleRows);
      VK_NEXT:  MoveCursorVerticallyNUpdateSelections(GetVisibleRows);
      VK_LEFT:  begin
                  OldCursorPos := CursorPos;
                  CursorPos := CursorPos - 1;
                  UpdateSelection(OldCursorPos);
                end;
      VK_RIGHT: begin
                  OldCursorPos := CursorPos;
                  CursorPos := CursorPos + 1;
                  UpdateSelection(OldCursorPos);
                end;
      VK_HOME:  begin
                  OldCursorPos := CursorPos;
                  CursorPos := GetMinCursorPosInRow;
                  UpdateSelection(OldCursorPos);
                end;
      VK_END:   begin
                  OldCursorPos := CursorPos;
                  CursorPos := GetMaxCursorPosInRow;
                  UpdateSelection(OldCursorPos);
                end;
    end
  else
    case Key of
      VK_UP:    begin MoveCursorVertically(-1); ResetSelection; end;
      VK_DOWN:  begin MoveCursorVertically(1); ResetSelection; end;
      VK_PRIOR: begin MoveCursorVertically(-GetVisibleRows); ResetSelection; end;
      VK_NEXT:  begin MoveCursorVertically(GetVisibleRows); ResetSelection; end;
      VK_LEFT:  begin CursorPos := CursorPos-1; ResetSelection; end;
      VK_RIGHT: begin CursorPos := CursorPos+1; ResetSelection; end;
      VK_HOME:  begin CursorPos := GetMinCursorPosInRow; ResetSelection; end;
      VK_END:   begin CursorPos := GetMaxCursorPosInRow; ResetSelection; end;
    end;
end;


function TKMMemo.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  Result := inherited KeyUp(Key, Shift) or KeyEventHandled(Key, Shift);
end;


procedure TKMMemo.MouseWheel(Sender: TObject; WheelDelta: Integer);
begin
  inherited;
  SetTopIndex(TopIndex - sign(WheelDelta));
end;


procedure TKMMemo.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var OldCursorPos: Integer;
begin
  inherited;

  Focusable := fSelectable and (fText <> ''); // Do not focus on empty Memo's
  // Update Focus now, because we need to focus on MouseDown, not on MouseUp as by default for all controls
  MasterParent.fMasterControl.UpdateFocus(Self);

  OldCursorPos := CursorPos;
  CursorPos := GetCursorPosAt(X, Y);

  if Focusable then
  begin
    //Try select on Shift + LMB click
    if (OldCursorPos <> -1) and (Shift = [ssLeft, ssShift]) then
      UpdateSelection(OldCursorPos)
    else begin
      ResetSelection;
    end;
    fSelectionInitialPos := CursorPos;
  end;
end;


procedure TKMMemo.MouseMove(X,Y: Integer; Shift: TShiftState);
var OldCursorPos: Integer;
    CharPos: TKMPoint;
begin
  inherited;
  if (ssLeft in Shift) and (fSelectionInitialPos <> -1) then
  begin
    CharPos := GetCharPosAt(X, Y);

    // To rotate text to top while selecting
    if (Y-AbsTop-3 < 0) and (TopIndex > 0) then
    begin
      Dec(CharPos.Y);
      SetTopIndex(TopIndex-1);
    end;
    // To rotate text to bottom while selecting
    if (Y-AbsTop-3 > fHeight)
      and (fScrollBar.Position < fScrollBar.MaxValue) then
    begin
      CharPos.Y := EnsureRange(CharPos.Y+1, 0, fItems.Count);
      SetTopIndex(TopIndex+1);
    end;

    OldCursorPos := CursorPos;
    CursorPos := PointToLinearPos(CharPos.X, CharPos.Y);;
    UpdateSelection(OldCursorPos);
  end;
end;


procedure TKMMemo.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  fSelectionInitialPos := -1;
end;


procedure TKMMemo.ControlMouseDown(Sender: TObject; Shift: TShiftState);
begin
  inherited;
  // Reset all, if other control was clicked
  if Sender <> Self then
  begin
    ResetSelection;
    Focusable := False;
    CursorPos := -1;
    MasterParent.fMasterControl.UpdateFocus(Self);
  end;
end;


procedure TKMMemo.FocusChanged(aFocused: Boolean);
begin
  if not aFocused then
  begin
    ResetSelection;
    CursorPos := -1;
    Focusable := False;
  end;
end;


procedure TKMMemo.Paint;
var I, PaintWidth, SelPaintTop, SelPaintHeight: Integer;
    BeforeSelectionText, SelectionText, RowText: UnicodeString;
    BeforeSelectionW, SelectionW, SelStartPosInRow, SelEndPosInRow, RowStartPos, RowEndPos: Integer;
    OffX, OffY: Integer;
begin
  inherited;
  if fScrollBar.Visible then
    PaintWidth := Width - fScrollBar.Width //Leave space for scrollbar
  else
    PaintWidth := Width; //List takes up the entire width

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, PaintWidth, Height, 1, 0.5);

  for I := 0 to Math.min(fItems.Count-1, GetVisibleRows - 1) do
  begin
    RowText := GetNoColorMarkupText(fItems[TopIndex+I]);
    RowStartPos := PointToLinearPos(0, TopIndex+I);
    RowEndPos := RowStartPos + Length(RowText);
    if HasSelection then
    begin
      SelStartPosInRow := fSelectionStart - RowStartPos;
      SelEndPosInRow := fSelectionEnd - RowStartPos;

      SelStartPosInRow := EnsureRange(SelStartPosInRow, 0, RowEndPos);
      SelEndPosInRow := EnsureRange(SelEndPosInRow, SelStartPosInRow, RowEndPos);

      if SelStartPosInRow <> SelEndPosInRow then
      begin
        BeforeSelectionText := Copy(RowText, 1, SelStartPosInRow);
        SelectionText := Copy(RowText, SelStartPosInRow+1, SelEndPosInRow - SelStartPosInRow);

        BeforeSelectionW := gRes.Fonts[fFont].GetTextSize(BeforeSelectionText).X;
        SelectionW := gRes.Fonts[fFont].GetTextSize(SelectionText).X;

        SelPaintHeight := fItemHeight;
        SelPaintTop := AbsTop+I*fItemHeight;
        if I = 0 then
        begin
          Dec(SelPaintHeight, 3);
          Inc(SelPaintTop, 3);
        end;

        TKMRenderUI.WriteShape(AbsLeft+4+BeforeSelectionW, SelPaintTop, min(SelectionW, Width-8), SelPaintHeight, clTextSelection);
      end;
    end;

    //Render text cursor
    if fSelectable and (csFocus in State) and ((TimeGet div 500) mod 2 = 0)
      and InRange(CursorPos, RowStartPos, RowEndPos) then
    begin
      OffX := AbsLeft + 2 + gRes.Fonts[fFont].GetTextSize(Copy(RowText, 1, CursorPos-RowStartPos)).X;
      OffY := AbsTop + 2 + I*fItemHeight;
      TKMRenderUI.WriteShape(OffX, OffY, 3, fItemHeight-4, $FFFFFFFF, $FF000000);
    end;
    TKMRenderUI.WriteText(AbsLeft+4, AbsTop+I*fItemHeight+3, Width-8, fItems.Strings[TopIndex+I] , fFont, taLeft);
  end;

end;


{ TKMListBox }
constructor TKMListBox.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fBackAlpha := 0.5;
  fItemHeight := 20;
  fItemIndex := -1;
  fItems := TStringList.Create;
  fFont := aFont;
  fAutoHideScrollBar := False; //Always show the scrollbar by default, then it can be turned off if required
  Focusable := True; //For up/down keys
  fSeparatorHeight := 0;
  fSeparatorTexts := TStringList.Create;
  fSeparatorFont := fnt_Antiqua; //Looks good on dark solid background
  fSeparatorColor := clListSeparatorShape;

  fScrollBar := TKMScrollBar.Create(aParent, aLeft+aWidth-20, aTop, 20, aHeight, sa_Vertical, aStyle);
  UpdateScrollBar; //Initialise the scrollbar
end;


destructor TKMListBox.Destroy;
begin
  fItems.Free;
  fSeparatorTexts.Free;
  inherited;
end;


procedure TKMListBox.SetLeft(aValue: Integer);
begin
  inherited;
  fScrollBar.Left := Left + Width - fScrollBar.Width;
end;


procedure TKMListBox.SetTop(aValue: Integer);
begin
  inherited;
  fScrollBar.Top := Top;
end;


procedure TKMListBox.SetHeight(aValue: Integer);
begin
  inherited;
  fScrollBar.Height := fHeight;
  UpdateScrollBar; //Since height has changed
end;


//Copy property to scrollbar. Otherwise it won't be rendered
procedure TKMListBox.SetVisible(aValue: Boolean);
begin
  inherited;
  fScrollBar.Visible := fVisible and (not fAutoHideScrollBar or fScrollBar.Enabled); //Hide scrollbar and its buttons
end;


function TKMListBox.GetSelfWidth: Integer;
begin
  if fScrollBar.Visible then
    Result := Width - fScrollBar.Width //Leave space for scrollbar
  else
    Result := Width; //List takes up the entire width
end;


function TKMListBox.GetTopIndex: Integer;
begin
  Result := fScrollBar.Position;
end;


procedure TKMListBox.SetTopIndex(aIndex: Integer);
begin
  fScrollBar.Position := aIndex;
end;


procedure TKMListBox.SetBackAlpha(aValue: single);
begin
  fBackAlpha := aValue;
  fScrollBar.BackAlpha := aValue;
end;


procedure TKMListBox.SetEnabled(aValue: Boolean);
begin
  inherited;
  fScrollBar.Enabled := aValue;
end;


//fItems.Count has changed
procedure TKMListBox.UpdateScrollBar;
begin
  fScrollBar.MaxValue := fItems.Count - GetVisibleRows;
  fScrollBar.Visible := fVisible and (not fAutoHideScrollBar or fScrollBar.Enabled);
  //Separators can not be used with scroll bar for now.
  //Scrollbar works line-wise, not pixel-wise,
  //so adding separators could cause visual issues
  //(list 'jumping' when there is or there is no separator, when separator width is not equal to line width)
  Assert(not (fScrollBar.Visible and (SeparatorsCount > 0)), 'Separators can not be used with scroll bar');
end;


procedure TKMListBox.Add(const aItem: UnicodeString; aTag: Integer = 0);
begin
  fItems.Add(aItem);
  SetLength(ItemTags, Length(ItemTags) + 1);
  ItemTags[Length(ItemTags)-1] := aTag;
  UpdateScrollBar;
end;


//Add separator just before aPosition item in list with aText on it
procedure TKMListBox.AddSeparator(aPosition: Integer; aText: String = '');
begin
  fSeparatorTexts.Add(aText);
  SetLength(fSeparatorPositions, Length(fSeparatorPositions) + 1);
  fSeparatorPositions[Length(fSeparatorPositions)-1] := aPosition;
  //Separators can not be used with scroll bar for now.
  //Scrollbar works line-wise, not pixel-wise,
  //so adding separators could cause visual issues
  //(list 'jumping' when there is or there is no separator, when separator width is not equal to line width)
  Assert(not fScrollBar.Visible, 'Separators can not be used with scroll bar');
end;


procedure TKMListBox.ClearSeparators;
begin
  fSeparatorTexts.Clear;
  SetLength(fSeparatorPositions, 0);
end;


procedure TKMListBox.Clear;
begin
  fItems.Clear;
  SetLength(ItemTags, 0);
  ClearSeparators;
  fItemIndex := -1;
  UpdateScrollBar;
end;


//Hide the scrollbar if it is not required (disabled) This is used for drop boxes.
procedure TKMListBox.SetAutoHideScrollBar(Value: boolean);
begin
  fAutoHideScrollBar := Value;
  UpdateScrollBar;
end;


function TKMListBox.Count: Integer;
begin
  Result := fItems.Count;
end;


function TKMListBox.Selected: Boolean;
begin
  Result := fItemIndex <> -1;
end;


function TKMListBox.SeparatorsCount: Integer;
begin
  Result := Length(fSeparatorPositions);
end;


function TKMListBox.GetVisibleRows: Integer;
begin
  Result := (fHeight - fSeparatorHeight*SeparatorsCount) div fItemHeight;
end;


function TKMListBox.GetItem(aIndex: Integer): UnicodeString;
begin
  Result := fItems[aIndex];
end;


function TKMListBox.GetSeparatorPos(aIndex: Integer): Integer;
begin
  Result := fSeparatorPositions[aIndex];
end;


//Get aIndex item top position, considering separators
function TKMListBox.GetItemTop(aIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := fItemHeight*aIndex;
  for I := 0 to Length(fSeparatorPositions) - 1 do
    if fSeparatorPositions[I] <= aIndex then
      Inc(Result, fSeparatorHeight);
end;


function TKMListBox.KeyDown(Key: Word; Shift: TShiftState): Boolean;
var
  OldIndex, NewIndex: Integer;
  PageScrolling: Boolean;
begin
  Result := Key in [VK_UP, VK_DOWN, VK_HOME, VK_END, VK_PRIOR, VK_NEXT];
  if inherited KeyDown(Key, Shift) then Exit;

  PageScrolling := False;
  OldIndex := fItemIndex;
  case Key of
    VK_UP:      NewIndex := fItemIndex - 1;
    VK_DOWN:    NewIndex := fItemIndex + 1;
    VK_HOME:    NewIndex := 0;
    VK_END:     NewIndex := Count - 1;
    VK_PRIOR:   begin
                    NewIndex := EnsureRange(fItemIndex - GetVisibleRows, 0, Count - 1);
                    PageScrolling := True;
                  end;
    VK_NEXT:    begin
                    NewIndex := EnsureRange(fItemIndex + GetVisibleRows, 0, Count - 1);
                    PageScrolling := True;
                  end;
    VK_RETURN:  begin
                  //Trigger click to hide drop downs
                  if Assigned(fOnClick) then
                    fOnClick(Self);
                  Exit;
                end;
    else        Exit;
  end;

  if InRange(NewIndex, 0, Count - 1) then
  begin
    fItemIndex := NewIndex;
    if PageScrolling then
      TopIndex := fItemIndex - (OldIndex - TopIndex) // Save position from the top of the list
    else if TopIndex < fItemIndex - (Height div fItemHeight) + 1 then //Moving down
      TopIndex := fItemIndex - (Height div fItemHeight) + 1
    else if TopIndex > fItemIndex then //Moving up
      TopIndex := fItemIndex;
  end;

  if Assigned(fOnChange) and (NewIndex <> OldIndex) then
    fOnChange(Self);
end;


procedure TKMListBox.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  MouseMove(X,Y,Shift); //Will change Position and call OnChange event
end;


procedure TKMListBox.MouseMove(X,Y: Integer; Shift: TShiftState);
  function GetItemIndex(aY: Integer): Integer;
  var
    I: Integer;
  begin
    Result := -1;
    for I := 0 to Min(fItems.Count, GetVisibleRows) - 1 do
      if InRange(aY, AbsTop + GetItemTop(I), AbsTop + GetItemTop(I) + fItemHeight) then
      begin
        Result := I;
        Exit;
      end;
  end;

var NewIndex: Integer;
begin
  inherited;

  if (ssLeft in Shift)
    and InRange(X, AbsLeft, AbsLeft + Width - (fScrollBar.Width * Byte(fScrollBar.Visible)))
    and InRange(Y, AbsTop, AbsTop + Height)
  then
  begin
    NewIndex := GetItemIndex(Y);
    if NewIndex <> -1 then
      NewIndex := NewIndex + TopIndex
    else
      Exit;

    if NewIndex > fItems.Count - 1 then
    begin
      //Double clicking not allowed if we are clicking past the end of the list, but keep last item selected
      fTimeOfLastClick := 0;
      NewIndex := fItems.Count - 1;
    end;

    if NewIndex <> fItemIndex then
    begin
      fItemIndex := NewIndex;
      fTimeOfLastClick := 0; //Double click shouldn't happen if you click on one server A, then server B
      if Assigned(fOnChange) then
        fOnChange(Self);
    end;
  end;
end;


procedure TKMListBox.MouseWheel(Sender: TObject; WheelDelta: Integer);
begin
  inherited;
  SetTopIndex(TopIndex - sign(WheelDelta));
  fScrollBar.Position := TopIndex; //Make the scrollbar move too when using the wheel
end;


procedure TKMListBox.Paint;
var
  I, PaintWidth: Integer;
  ShapeColor, OutlineColor: TColor4;
begin
  inherited;

  if fScrollBar.Visible then
    PaintWidth := Width - fScrollBar.Width //Leave space for scrollbar
  else
    PaintWidth := Width; //List takes up the entire width

  // Draw background
  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, PaintWidth, Height, 1, fBackAlpha);

  // Draw selection outline and rectangle (shape)
  if (fItemIndex <> -1) and InRange(fItemIndex - TopIndex, 0, GetVisibleRows - 1) then
  begin
    if IsFocused then
    begin
      ShapeColor := clListSelShape;
      OutlineColor := clListSelOutline;
    end else begin
      ShapeColor := clListSelShapeUnfocused;
      OutlineColor := clListSelOutlineUnfocused;
    end;
    TKMRenderUI.WriteShape(AbsLeft, AbsTop + GetItemTop(fItemIndex) - fItemHeight*TopIndex, PaintWidth, fItemHeight, ShapeColor, OutlineColor);
  end;

  // Draw text lines
  for I := 0 to Min(fItems.Count, GetVisibleRows) - 1 do
    TKMRenderUI.WriteText(AbsLeft + 4, AbsTop + GetItemTop(I) + 3, PaintWidth - 8, fItems.Strings[TopIndex+I] , fFont, taLeft);

  // Draw separators
  for I := 0 to Length(fSeparatorPositions) - 1 do
  begin
    TKMRenderUI.WriteShape(AbsLeft, AbsTop + GetItemTop(fSeparatorPositions[I]) - fSeparatorHeight,
                           PaintWidth - 1, fSeparatorHeight, fSeparatorColor);
    if fSeparatorTexts[I] <> '' then
      TKMRenderUI.WriteText(AbsLeft + 4, AbsTop + GetItemTop(fSeparatorPositions[I]) - fSeparatorHeight,
                            PaintWidth - 8, fSeparatorTexts[I], fSeparatorFont, taCenter)
  end;
end;


{ TKMListHeader }
constructor TKMListHeader.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  BackAlpha := 0.5;
  EdgeAlpha := 0.75;
  fSortDirection := sdNone;
  fSortIndex := -1;
end;


destructor TKMListHeader.Destroy;
begin
  ClearColumns;

  inherited;
end;


procedure TKMListHeader.ClearColumns;
var
  I: Integer;
begin
  for I := 0 to fCount - 1 do
    FreeAndNil(fColumns[I]);
end;


function TKMListHeader.GetColumnIndex(X: Integer): Integer;
var I: Integer;
begin
  Result := -1;

  for I := 0 to fCount - 1 do
    if X - AbsLeft > fColumns[I].Offset then
      Result := I;
end;


function TKMListHeader.GetColumn(aIndex: Integer): TKMListHeaderColumn;
begin
  Result := fColumns[aIndex];
end;


function TKMListHeader.GetColumnWidth(aIndex: Integer): Integer;
begin
  if aIndex = fCount - 1 then
    Result := Width - fColumns[aIndex].Offset
  else
    Result := fColumns[aIndex+1].Offset - fColumns[aIndex].Offset;
end;


//We know we were clicked and now we can decide what to do
procedure TKMListHeader.DoClick(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var ColumnID: Integer;
begin
  //do not invoke inherited here, to fully override parent DoClick method
  ColumnID := GetColumnIndex(X);
  if (ColumnID <> -1) and Assigned(OnColumnClick) then
  begin
    //We could process the clicks here (i.e. do the sorting inplace)
    //but there are various circumstances where plain string sorting will look wrong
    //and the ListBox just misses the knowledge to do it right:
    //MP game status (sort by type), ping (sort 1>9), playercount (sort 9>1), dates (sort by TDateTime)
    //Let the UI communicate to Game and do it right

    //Apply sorting to the column, toggling the state, sdDown is default
    if fSortIndex = ColumnID then
      if fSortDirection = sdDown then
        fSortDirection := sdUp
      else
        fSortDirection := sdDown
    else
      fSortDirection := sdDown;
    fSortIndex := ColumnID;
    OnColumnClick(ColumnID);
  end
  else
    inherited; //Process the usual clicks if e.g. there are no columns
end;


procedure TKMListHeader.SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word);
var
  I: Integer;
begin
  Assert(Length(aColumns) = Length(aColumnOffsets));

  fFont := aFont;

  ClearColumns;

  fCount := Length(aColumns);
  SetLength(fColumns, fCount);
  for I := 0 to fCount - 1 do
  begin
    fColumns[I] := TKMListHeaderColumn.Create;
    fColumns[I].Caption := aColumns[I];
    fColumns[I].Offset := aColumnOffsets[I];
  end;
end;


procedure TKMListHeader.MouseMove(X, Y: Integer; Shift: TShiftState);
begin
  inherited;
  fColumnHighlight := GetColumnIndex(X);
end;


procedure TKMListHeader.Paint;
var
  I: Integer;
  ColumnLeft: Integer;
  ColumnWidth: Integer;
  TextSize: TKMPoint;
begin
  inherited;

  for I := 0 to fCount - 1 do
  begin
    if I < fCount - 1 then
      ColumnWidth := fColumns[I+1].Offset - fColumns[I].Offset
    else
      ColumnWidth := Width - fColumns[I].Offset;

    if ColumnWidth <= 0 then Break;

    ColumnLeft := AbsLeft + fColumns[I].Offset;

    TKMRenderUI.WriteBevel(ColumnLeft, AbsTop, ColumnWidth, Height, EdgeAlpha, BackAlpha);
    if Assigned(OnColumnClick) and (csOver in State) and (fColumnHighlight = I) then
      TKMRenderUI.WriteShape(ColumnLeft, AbsTop, ColumnWidth, Height, $20FFFFFF);

    if fColumns[I].Glyph.ID <> 0 then
      TKMRenderUI.WritePicture(ColumnLeft + 4, AbsTop, ColumnWidth - 8, Height, [], fColumns[I].Glyph.RX, fColumns[I].Glyph.ID)
    else
    begin
      TextSize := gRes.Fonts[fFont].GetTextSize(fColumns[I].Caption);
      TKMRenderUI.WriteText(ColumnLeft + 4, AbsTop + (Height - TextSize.Y) div 2 + 2, ColumnWidth - 8, fColumns[I].Caption, fFont, fTextAlign);
    end;

    if Assigned(OnColumnClick) and (fSortIndex = I) then
      case fSortDirection of
        sdDown: TKMRenderUI.WritePicture(ColumnLeft + ColumnWidth - 4-10, AbsTop + 6, 10, 11, [], rxGui, 60);
        sdUp:   TKMRenderUI.WritePicture(ColumnLeft + ColumnWidth - 4-10, AbsTop + 6, 10, 11, [], rxGui, 59);
      end;
  end;
end;


{ TKMColumnListBox }
constructor TKMColumnBox.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle);
const DEF_HEADER_HEIGHT = 24;
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);
  fFont       := aFont;
  fItemHeight := 20;
  fItemIndex  := -1;
  fShowHeader := True;
  SearchColumn := -1; //Disabled by default
  Focusable := True; //For up/down keys

  fHeader := TKMListHeader.Create(aParent, aLeft, aTop, aWidth - fItemHeight, DEF_HEADER_HEIGHT);

  fScrollBar := TKMScrollBar.Create(aParent, aLeft+aWidth-fItemHeight, aTop, fItemHeight, aHeight, sa_Vertical, aStyle);
  UpdateScrollBar; //Initialise the scrollbar

  SetEdgeAlpha(1);
  SetBackAlpha(0.5);
end;


destructor TKMColumnBox.Destroy;
begin
  ClearColumns;

  inherited;
end;


procedure TKMColumnBox.SetSearchColumn(aValue: ShortInt);
begin
  fSearchColumn := aValue;
end;


procedure TKMColumnBox.SetShowHeader(aValue: Boolean);
begin
  fHeader.Visible := aValue;
  fShowHeader := aValue;
end;


procedure TKMColumnBox.SetLeft(aValue: Integer);
begin
  inherited;

  fHeader.Left := Left;
  fScrollBar.Left := Left + Width - fScrollBar.Width;
end;


procedure TKMColumnBox.SetTop(aValue: Integer);
begin
  inherited;

  //Update header and scrollbar so that their Top matched
  fHeader.Top := Top;
  fScrollBar.Top := Top;
end;


procedure TKMColumnBox.SetWidth(aValue: Integer);
begin
  inherited;

  fHeader.Width := Width;
  fScrollBar.Left := Left + Width - fScrollBar.Width;
end;


procedure TKMColumnBox.SetHeight(aValue: Integer);
begin
  inherited;
  fScrollBar.Height := fHeight;
  UpdateScrollBar; //Since height has changed
end;


procedure TKMColumnBox.SetItemIndex(const Value: Smallint);
begin
  if InRange(Value, 0, RowCount - 1) then
    fItemIndex := Value
  else
    fItemIndex := -1;
end;


procedure TKMColumnBox.SetOnColumnClick(const Value: TIntegerEvent);
begin
  fHeader.OnColumnClick := Value;
end;


procedure TKMColumnBox.SetSortDirection(aDirection: TSortDirection);
begin
  fHeader.SortDirection := aDirection;
end;


procedure TKMColumnBox.SetSortIndex(aIndex: Integer);
begin
  fHeader.SortIndex := aIndex;
end;


//Copy property to scrollbar. Otherwise it won't be rendered
procedure TKMColumnBox.SetVisible(aValue: Boolean);
begin
  inherited;
  fHeader.Visible := fVisible and fShowHeader;
  fScrollBar.Visible := fVisible and fScrollBar.Enabled; //Hide scrollbar and its buttons
end;


function TKMColumnBox.GetSelfAbsTop: Integer;
begin
  Result := AbsTop + (fHeader.Height + 1) * Byte(fShowHeader);
end;


function TKMColumnBox.GetSelfHeight: Integer;
begin
  Result := Height - (fHeader.Height + 1) * Byte(fShowHeader);
end;


function TKMColumnBox.GetSelfWidth: Integer;
begin
  if fScrollBar.Visible then
    Result := Width - fScrollBar.Width //Leave space for scrollbar
  else
    Result := Width; //List takes up the entire width
end;


function TKMColumnBox.GetTopIndex: Integer;
begin
  Result := fScrollBar.Position;
end;


function TKMColumnBox.GetVisibleRows: Integer;
begin
  Result := Floor(GetVisibleRowsExact);
end;


function TKMColumnBox.GetVisibleRowsExact: Single;
begin
  Result := (fHeight - fHeader.Height * Byte(fShowHeader)) / fItemHeight;
end;


function TKMColumnBox.IsSelected: Boolean;
begin
  Result := fItemIndex <> -1;
end;


procedure TKMColumnBox.SetTopIndex(aIndex: Integer);
begin
  fScrollBar.Position := aIndex;
end;


procedure TKMColumnBox.SetBackAlpha(aValue: Single);
begin
  fBackAlpha := aValue;
  fHeader.BackAlpha := aValue;
  fScrollBar.BackAlpha := aValue;
end;


procedure TKMColumnBox.SetEdgeAlpha(aValue: Single);
begin
  fEdgeAlpha := aValue;
  fHeader.EdgeAlpha := aValue;
  fScrollBar.EdgeAlpha := aValue;
end;


procedure TKMColumnBox.SetEnabled(aValue: Boolean);
begin
  inherited;
  fHeader.Enabled := aValue;
  fScrollBar.Enabled := aValue;
end;


function TKMColumnBox.GetColumn(aIndex: Integer): TKMListColumn;
begin
  Result := fColumns[aIndex];
end;


function TKMColumnBox.GetItem(aIndex: Integer): TKMListRow;
begin
  if InRange(aIndex, 0, RowCount - 1) then
    Result := Rows[aIndex]
  else
    raise Exception.Create('Cannot get Item with index ' + IntToStr(aIndex));
end;


function TKMColumnBox.GetSelectedItem: TKMListRow;
begin
  if IsSelected then
    Result := Rows[fItemIndex]
  else
    raise Exception.Create('No selected item found');
end;


function TKMColumnBox.GetOnColumnClick: TIntegerEvent;
begin
  Result := fHeader.OnColumnClick;
end;


function TKMColumnBox.GetSortDirection: TSortDirection;
begin
  Result := fHeader.SortDirection;
end;


function TKMColumnBox.GetSortIndex: Integer;
begin
  Result := fHeader.SortIndex;
end;


//fRowCount or Height has changed
procedure TKMColumnBox.UpdateScrollBar;
begin
  fScrollBar.MaxValue := fRowCount - (fHeight - fHeader.Height * Byte(fShowHeader)) div fItemHeight;
  Assert(fScrollBar.MaxValue >= fScrollBar.MinValue);
  fScrollBar.Visible := fVisible and (fScrollBar.MaxValue <> fScrollBar.MinValue);
end;


//If we don't add columns there will be Assert on items add
procedure TKMColumnBox.SetColumns(aHeaderFont: TKMFont; aCaptions: array of string; aOffsets: array of Word);
var
  I: Integer;
begin
  Assert(Length(aCaptions) = Length(aOffsets));

  Clear; //We don't want to conflict with already added rows elements
  ClearColumns;

  fHeader.SetColumns(aHeaderFont, aCaptions, aOffsets);

  SetLength(fColumns, fHeader.ColumnCount);
  for I := 0 to fHeader.ColumnCount - 1 do
  begin
    fColumns[I] := TKMListColumn.Create;
    fColumns[I].Font := fFont; //Reset to default font
    fColumns[I].TextAlign := taLeft; //Default alignment
    fColumns[I].TriggerOnChange := True; //by default all columns trigger OnChange
  end;
end;


procedure TKMColumnBox.AddItem(aItem: TKMListRow);
begin
  Assert(fHeader.ColumnCount > 0);
  Assert(Length(aItem.Cells) = fHeader.ColumnCount);

  if fRowCount >= Length(Rows) then
    SetLength(Rows, fRowCount + 16);

  Rows[fRowCount] := aItem;

  Inc(fRowCount);
  UpdateScrollBar;
end;


procedure TKMColumnBox.Clear;
begin
  fRowCount := 0;
  fItemIndex := -1;
  UpdateScrollBar;
end;


procedure TKMColumnBox.ClearColumns;
var
  I: Integer;
begin
  for I := 0 to fHeader.ColumnCount - 1 do
    FreeAndNil(fColumns[I]);
end;


function TKMColumnBox.KeyDown(Key: Word; Shift: TShiftState): Boolean;
var
  OldIndex, NewIndex: Integer;
  PageScrolling: Boolean;
begin
  Result := (Key in [VK_UP, VK_DOWN, VK_HOME, VK_END, VK_PRIOR, VK_NEXT]) and not HideSelection;
  if inherited KeyDown(Key, Shift) then Exit;

  if HideSelection then Exit; //Can't change selection if it's hidden

  PageScrolling := False;
  OldIndex := fItemIndex;
  case Key of
    VK_UP:      NewIndex := fItemIndex - 1;
    VK_DOWN:    NewIndex := fItemIndex + 1;
    VK_HOME:    NewIndex := 0;
    VK_END:     NewIndex := fRowCount - 1;
    VK_PRIOR:   begin
                  NewIndex := EnsureRange(fItemIndex - GetVisibleRows, 0, fRowCount - 1);
                  PageScrolling := True;
                end;
    VK_NEXT:    begin
                  NewIndex := EnsureRange(fItemIndex + GetVisibleRows, 0, fRowCount - 1);
                  PageScrolling := True;
                end;
    VK_RETURN:  begin
                  //Trigger click to hide drop downs
                  if Assigned(fOnClick) then
                    fOnClick(Self);
                    //Double click on Enter
                    if Assigned(fOnDoubleClick) then
                      fOnDoubleClick(Self);
                  Exit;
                end;
    else        Exit;
  end;

  if InRange(NewIndex, 0, fRowCount - 1) then
  begin
    ItemIndex := NewIndex;
    if PageScrolling then
      TopIndex := fItemIndex - (OldIndex - TopIndex) // Save position from the top of the list
    else if TopIndex < fItemIndex - GetVisibleRows + 1 then //Moving down
    TopIndex := fItemIndex - GetVisibleRows + 1
    else if TopIndex > fItemIndex then //Moving up
    TopIndex := fItemIndex;
  end;

  if Assigned(fOnChange) and (OldIndex <> NewIndex) then
    fOnChange(Self);
end;


procedure TKMColumnBox.KeyPress(Key: Char);
var
  I: Integer;
begin
  if PassAllKeys then
    Exit
  else
  begin
    //KeyPress used only for key input search, do not allow unsupported Keys.
    //Otherwise fOnChange will be invoked on any key pressed
    if not IsCharAllowed(Key, acFileName) then Exit;

    if SearchColumn = -1 then
      Exit;

    //Allow to type several characters in a row to pick some item
    if GetTimeSince(fLastKeyTime) < 1000 then
      fSearch := fSearch + Key
    else
      fSearch := Key;

    fLastKeyTime := TimeGet;

    for I := 0 to fRowCount - 1 do
    if AnsiStartsText(fSearch, Rows[I].Cells[SearchColumn].Caption) then
    begin
      ItemIndex := I;
      TopIndex := fItemIndex - GetVisibleRows div 2;
      Break;
    end;

    if Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


//Update mouse over row/cell positions (fMouseOver* variables)
procedure TKMColumnBox.UpdateMouseOverPosition(X,Y: Integer);
var I, CellLeftOffset, CellRightOffset: Integer;
begin
  if  InRange(X, AbsLeft, AbsLeft + Width - fScrollBar.Width * Byte(fScrollBar.Visible))
  and InRange(Y, AbsTop + fHeader.Height*Byte(fHeader.Visible), AbsTop + fHeader.Height*Byte(fHeader.Visible) + Floor(GetVisibleRowsExact * fItemHeight) - 1) then
  begin
    fMouseOverRow := TopIndex + (Y - AbsTop - fHeader.Height * Byte(fShowHeader)) div fItemHeight;
    for I := 0 to fHeader.ColumnCount - 1 do
    begin
      CellLeftOffset := AbsLeft + fHeader.Columns[I].Offset;
      if I = fHeader.ColumnCount - 1 then
        CellRightOffset := AbsLeft + Width - fScrollBar.Width * Byte(fScrollBar.Visible)
      else
        CellRightOffset := AbsLeft + fHeader.Columns[I+1].Offset - 1;
      if InRange(X, CellLeftOffset, CellRightOffset) then
        fMouseOverCell := KMPoint(I, fMouseOverRow);
    end;
  end else begin
    fMouseOverRow := -1;
    fMouseOverCell := KMPOINT_INVALID_TILE;
  end;
end;


procedure TKMColumnBox.DoClick(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
var IsClickHandled: Boolean;
begin
  //do not invoke inherited here, to fully override parent DoClick method
  IsClickHandled := False;

  if (Button = mbLeft) and Assigned(fOnCellClick) and not KMSamePoint(fMouseOverCell, KMPOINT_INVALID_TILE) then
    IsClickHandled := fOnCellClick(Self, fMouseOverCell.X, fMouseOverCell.Y);

  //Let propagate click event only when OnCellClick did not handle it
  if not IsClickHandled then
  begin
    inherited DoClick(X, Y, Shift, Button);
    if Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


procedure TKMColumnBox.UpdateItemIndex(Shift: TShiftState);
var NewIndex: Integer;
begin
  if not (ssLeft in Shift) or (fMouseOverRow = -1) then
    Exit;

  NewIndex := fMouseOverRow;

  if NewIndex >= fRowCount then
  begin
    //Double clicking not allowed if we are clicking past the end of the list, but keep last item selected
    fTimeOfLastClick := 0;
    NewIndex := -1;
  end;

  if InRange(NewIndex, 0, fRowCount - 1) and (NewIndex <> fItemIndex)  then
  begin
    fTimeOfLastClick := 0; //Double click shouldn't happen if you click on one server A, then server B
    ItemIndex := NewIndex;
    if not KMSamePoint(fMouseOverCell, KMPOINT_INVALID_TILE) and Columns[fMouseOverCell.X].TriggerOnChange
      and Assigned(fOnChange) then
      fOnChange(Self);
  end;
end;


procedure TKMColumnBox.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  UpdateMouseOverPosition(X, Y);
  UpdateItemIndex(Shift);
  //Lets do DoClick here instead of MouseUp event handler, because of some TKMColumnBox specific logic
  if (csDown in State) then
  begin
    State := State - [csDown];

    //Send Click events
    DoClick(X, Y, Shift, Button);
  end;
end;


procedure TKMColumnBox.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  inherited;
  UpdateMouseOverPosition(X, Y);
  UpdateItemIndex(Shift);
end;


procedure TKMColumnBox.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  //We handle normal MouseUp event in MouseDown, so just hide ancestor MouseUp here
end;


procedure TKMColumnBox.MouseWheel(Sender: TObject; WheelDelta: Integer);
begin
  inherited;
  SetTopIndex(TopIndex - Sign(WheelDelta));
  fScrollBar.Position := TopIndex; //Make the scrollbar move too when using the wheel
end;


procedure TKMColumnBox.DoPaintLine(aIndex: Integer; X, Y: Integer; PaintWidth: Integer; aAllowHighlight: Boolean = True);
var ColumnsToShow: array of Boolean;
    I: Integer;
begin
  SetLength(ColumnsToShow, Length(fColumns));
  for I := Low(ColumnsToShow) to High(ColumnsToShow) do
    ColumnsToShow[I] := True; // show all columns by default
  DoPaintLine(aIndex, X, Y, PaintWidth, ColumnsToShow, aAllowHighlight);
end;


procedure TKMColumnBox.DoPaintLine(aIndex: Integer; X, Y: Integer; PaintWidth: Integer; aColumnsToShow: array of Boolean; aAllowHighlight: Boolean = True);
  function IsHighlightOverCell(aCellIndex: Integer): Boolean;
  begin
    Result := aAllowHighlight
                and Rows[aIndex].Cells[aCellIndex].HighlightOnMouseOver 
                and (fMouseOverCell.X = aCellIndex) and (fMouseOverCell.Y = aIndex)
                and (csOver in State);
  end;
  
var
  I: Integer;
  AvailWidth, HiddenColumnsTotalWidth: Integer;
  TextSize: TKMPoint;
  Color: Cardinal;
begin
  Assert(Length(fColumns) = Length(aColumnsToShow));
  HiddenColumnsTotalWidth := 0;
  for I := 0 to fHeader.ColumnCount - 1 do
  begin
    if not aColumnsToShow[I] then
    begin
      Inc(HiddenColumnsTotalWidth, fHeader.ColumnWidth[I]);
      Continue;
    end;
    //Determine available width
    if I = fHeader.ColumnCount - 1 then
      AvailWidth := PaintWidth - 4 - fHeader.Columns[I].Offset - 4
    else
      AvailWidth := fHeader.Columns[I+1].Offset - fHeader.Columns[I].Offset - 4;
    //Trim the width based on our allowed PaintWidth
    AvailWidth := Min(AvailWidth, PaintWidth - fHeader.Columns[I].Offset);

    if AvailWidth <= 0 then Continue; //If the item overflows our allowed PaintWidth do not paint it

    //Paint column
    if Rows[aIndex].Cells[I].Pic.ID <> 0 then
      TKMRenderUI.WritePicture(X + 4 + fHeader.Columns[I].Offset - HiddenColumnsTotalWidth, Y + 1,
                             AvailWidth, fItemHeight, [],
                             Rows[aIndex].Cells[I].Pic.RX,
                             Rows[aIndex].Cells[I].Pic.ID,
                             Rows[aIndex].Cells[I].Enabled,
                             Rows[aIndex].Cells[I].Color,
                             0.4*Byte(IsHighlightOverCell(I) or (HighlightOnMouseOver and (csOver in State) and (fMouseOverRow = aIndex))));

    if Rows[aIndex].Cells[I].Caption <> '' then
      if Rows[aIndex].Cells[I].Hint <> '' then
      begin
        TextSize := gRes.Fonts[fFont].GetTextSize(Rows[aIndex].Cells[I].Caption);
        TKMRenderUI.WriteText(X + 4 + fHeader.Columns[I].Offset - HiddenColumnsTotalWidth,
                            Y + 4,
                            AvailWidth,
                            Rows[aIndex].Cells[I].Caption,
                            fColumns[I].Font, fColumns[I].TextAlign, Rows[aIndex].Cells[I].Color);
        TKMRenderUI.WriteText(X + 4 + fHeader.Columns[I].Offset - HiddenColumnsTotalWidth,
                            Y + fItemHeight div 2 + 1,
                            AvailWidth,
                            Rows[aIndex].Cells[I].Hint,
                            fColumns[I].HintFont, fColumns[I].TextAlign, $FFB0B0B0);
      end else
      begin
        TextSize := gRes.Fonts[fFont].GetTextSize(Rows[aIndex].Cells[I].Caption);
        if aAllowHighlight
          and ((HighlightOnMouseOver and (csOver in State) and (fMouseOverRow = aIndex))
          or (HighlightError and (aIndex = ItemIndex))
          or IsHighlightOverCell(I)) then
          Color := Rows[aIndex].Cells[I].HighlightColor
        else
          Color := Rows[aIndex].Cells[I].Color;
          
        if not fEnabled then
          Color := ReduceBrightness(Color, 136);
        TKMRenderUI.WriteText(X + 4 + fHeader.Columns[I].Offset - HiddenColumnsTotalWidth,
                            Y + (fItemHeight - TextSize.Y) div 2 + 2,
                            AvailWidth,
                            Rows[aIndex].Cells[I].Caption,
                            fColumns[I].Font, fColumns[I].TextAlign, Color);
      end;
  end;
end;


procedure TKMColumnBox.Paint;
var
  I, PaintWidth, MaxItem, Y: Integer;
  OutlineColor, ShapeColor: TColor4;
begin
  inherited;

  if fScrollBar.Visible then
    PaintWidth := Width - fScrollBar.Width //Leave space for scrollbar
  else
    PaintWidth := Width; //List takes up the entire width

  fHeader.Width := PaintWidth;

  Y := AbsTop + fHeader.Height * Byte(fShowHeader);
  MaxItem := GetVisibleRows;

  TKMRenderUI.WriteBevel(AbsLeft, Y, PaintWidth, Height - fHeader.Height * Byte(fShowHeader), fEdgeAlpha, fBackAlpha);

  //Grid lines should be below selection focus
  if fShowLines then
    for I := 0 to Math.Min(fRowCount - 1, MaxItem) do
      TKMRenderUI.WriteShape(AbsLeft+1, Y + I * fItemHeight - 1, PaintWidth - 2, 1, $FFBBBBBB);

  TKMRenderUI.SetupClipY(AbsTop, AbsTop + Height - 1);

  //Selection highlight
  if not HideSelection
    and (fItemIndex <> -1)
    and InRange(ItemIndex - TopIndex, 0, MaxItem) then
  begin

    if IsFocused then
    begin
      ShapeColor := clListSelShape;//$88888888;
      OutlineColor := clListSelOutline;//$FFFFFFFF;
    end else begin
      ShapeColor := clListSelShapeUnfocused;//$66666666;
      OutlineColor := clListSelOutlineUnfocused;//$FFA0A0A0;
    end;

    TKMRenderUI.WriteShape(AbsLeft, Y + fItemHeight * (fItemIndex - TopIndex), PaintWidth, fItemHeight, ShapeColor);
    TKMRenderUI.WriteOutline(AbsLeft, Y + fItemHeight * (fItemIndex - TopIndex), PaintWidth, fItemHeight, 1 + Byte(fShowLines), OutlineColor);
  end;

  //Paint rows text and icons above selection for clear visibility
  for I := 0 to Math.min(fRowCount - TopIndex - 1, MaxItem) do
    DoPaintLine(TopIndex + I, AbsLeft, Y + I * fItemHeight, PaintWidth);

  TKMRenderUI.ReleaseClipY;
end;


{ TKMPopUpMenu }
constructor TKMPopUpMenu.Create(aParent: TKMPanel; aWidth: Integer);
begin
  inherited Create(aParent, 0, 0, aWidth, 0);

  fShapeBG := TKMShape.Create(Self, 0, 0, aParent.Width, aParent.Height);
  fShapeBG.AnchorsStretch;
  fShapeBG.OnClick := MenuHide;
  fShapeBG.Hide;

  fList := TKMColumnBox.Create(Self, 0, 0, aWidth, 0, fnt_Grey, bsMenu);
  fList.AnchorsStretch;
  fList.BackAlpha := 0.8;
  fList.Focusable := False;
  fList.SetColumns(fnt_Grey, [''], [0]);
  fList.ShowHeader := False;
  fList.OnClick := MenuClick;
  fList.Hide;

  Hide;
end;


procedure TKMPopUpMenu.Clear;
begin
  fList.Clear;
end;


function TKMPopUpMenu.GetItemIndex: Integer;
begin
  Result := fList.ItemIndex;
end;


function TKMPopUpMenu.GetItemTag(aIndex: Integer): Integer;
begin
  Result := fList.Rows[aIndex].Tag;
end;


procedure TKMPopUpMenu.SetItemIndex(aValue: Integer);
begin
  fList.ItemIndex := aValue;
end;


procedure TKMPopUpMenu.AddItem(const aCaption: UnicodeString; aTag: Integer = 0);
begin
  fList.AddItem(MakeListRow([aCaption], aTag));
  Height := fList.ItemHeight * fList.RowCount;
end;


procedure TKMPopUpMenu.UpdateItem(aIndex: Integer; const aCaption: UnicodeString);
begin
  fList.Rows[aIndex].Cells[0].Caption := aCaption;
end;


procedure TKMPopUpMenu.MenuClick(Sender: TObject);
begin
  if Assigned(fOnClick) then
    fOnClick(Self);

  MenuHide(Self);
end;


procedure TKMPopUpMenu.MenuHide(Sender: TObject);
begin
  Hide;
  fList.Hide;
  fShapeBG.Hide;
end;


procedure TKMPopUpMenu.HideMenu;
begin
  MenuHide(nil);
end;


procedure TKMPopUpMenu.ShowAt(X, Y: Integer);
begin
  fList.AbsLeft := X;
  fList.AbsTop := Y;

  //Reset previously selected item
  fList.ItemIndex := -1;

  Show;
  fShapeBG.Show;
  fList.Show;
end;


{ TKMPopUpPanel }
constructor TKMPopUpPanel.Create(aParent: TKMPanel; aWidth, aHeight: Integer; const aCaption: UnicodeString = '');
begin
  inherited Create(aParent, (aParent.Width div 2) - (aWidth div 2), (aParent.Height div 2) - (aHeight div 2), aWidth, aHeight);

  Font := fnt_Outline;
  FontColor := icWhite;
  Caption := aCaption;

  TKMBevel.Create(Self, -1000,  -1000, 4000, 4000);

  ImageBG := TKMImage.Create(Self, -20, -50, aWidth + 40, aHeight + 60, 15, rxGuiMain);
  ImageBG.ImageStretch;

  BevelBG := TKMBevel.Create(Self, 0, 0, aWidth, aHeight);

  AnchorsCenter;
  Hide;
end;


procedure TKMPopUpPanel.Paint;
begin
  inherited Paint;

  TKMRenderUI.WriteText(AbsLeft, AbsTop + 10, Width, Caption, Font, taCenter, FontColor);
end;


procedure TKMPopUpPanel.SetHeight(aValue: Integer);
begin
  inherited;
  UpdateSizes;
end;


procedure TKMPopUpPanel.SetWidth(aValue: Integer);
begin
  inherited;
  UpdateSizes;
end;


procedure TKMPopUpPanel.UpdateSizes;
begin
  ImageBG.Width := Width + 40;
  ImageBG.Height := Height + 60;
  BevelBG.Width := Width;
  BevelBG.Height := Height;
end;


{ TKMDropCommon }
constructor TKMDropCommon.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aStyle: TKMButtonStyle; aAutoClose: Boolean = True);
var
  P: TKMPanel;
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fDropCount := 10;
  fDropUp := False;
  fFont := aFont;

  fButton := TKMButton.Create(aParent, aLeft+aWidth-aHeight, aTop, aHeight, aHeight, 590, rxGui, aStyle);
  fButton.OnClick := ButtonClick;
  fButton.MakesSound := False;

  P := MasterParent;
  fShape := TKMShape.Create(P, 0, 0, P.Width, P.Height);
  fShape.AnchorsStretch;
  fShape.fOnClick := ListHide;

  fAutoClose := aAutoClose;
end;


procedure TKMDropCommon.UpdateVisibility;
begin
  inherited;
  if not Visible then
    CloseList;
end;


procedure TKMDropCommon.ButtonClick(Sender: TObject);
begin
  //Call the DoDlick event to show the list AND generate DropBox.OnClick event
  DoClick(fButton.AbsLeft + fButton.Width div 2, fButton.AbsTop + fButton.Height div 2, [], mbLeft);
end;


procedure TKMDropCommon.ListShow(Sender: TObject);
begin
  if ListVisible then
  begin
    ListHide(nil);
    Exit;
  end;

  if fAutoClose and (Count > 0) then
    fShape.Show;

  if Assigned(fOnShowList) then fOnShowList(Self);
end;


procedure TKMDropCommon.DoClick(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  //do not invoke inherited here, to fully override parent DoClick method

  //It's common behavior when click on dropbox will show the list
  if fAutoClose then
    ListShow(Self)
  else
    if not ListVisible then
    begin
      fButton.TexId := 591;
      ListShow(Self)
    end else begin
      fButton.TexId := 590;
      ListHide(Self);
    end;

  inherited;
end;


//Handle KeyDown on List
function TKMDropCommon.ListKeyDown(Sender: TObject; Key: Word; Shift: TShiftState): Boolean;
begin
  if fAutoClose and (Key = VK_ESCAPE) then // Close List on ESC, if autoclosable
  begin
    ListHide(nil);
    Result := True;
  end else
    Result := False;
end;


procedure TKMDropCommon.ListClick(Sender: TObject);
begin
  //No need to call fOnChange here since ListChange was already called
  if fAutoClose then ListHide(nil);
end;


procedure TKMDropCommon.ListChange(Sender: TObject);
begin
  if (ItemIndex <> -1) then
    if Assigned(fOnChange) then fOnChange(Self);
end;


procedure TKMDropCommon.ListHide(Sender: TObject);
begin
  fShape.Hide;
end;


procedure TKMDropCommon.SetEnabled(aValue: Boolean);
begin
  inherited;
  fButton.Enabled := aValue;
end;


procedure TKMDropCommon.CloseList;
begin
  ListHide(nil);
end;


procedure TKMDropCommon.SetTop(aValue: Integer);
begin
  inherited;
  //Stick the button to us
  fButton.Top := Top;
end;


procedure TKMDropCommon.SetVisible(aValue: Boolean);
begin
  inherited;
  fButton.Visible := aValue;
  if not aValue then ListHide(Self);
end;


procedure TKMDropCommon.Paint;
begin
  inherited;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width, Height);

  // Make sure the list stays where it needs to be relative DropBox (e.g. on window resize)
  UpdateDropPosition;
end;


{ TKMDropList }
constructor TKMDropList.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; aDefaultCaption: UnicodeString;
                               aStyle: TKMButtonStyle; aAutoClose: Boolean = True; aBackAlpha: Single = 0.85);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aFont, aStyle, aAutoClose);

  fDefaultCaption := aDefaultCaption;

  fListTopIndex := 0;

  fList := TKMListBox.Create(MasterParent, 0, 0, aWidth, 0, fFont, aStyle);
  fList.Height := fList.ItemHeight * fDropCount;
  fList.AutoHideScrollBar := True; //A drop box should only have a scrollbar if required
  fList.BackAlpha := aBackAlpha;
  fList.fOnClick := ListClick;
  fList.fOnChange := ListChange;

  ListHide(nil);
  fList.OnKeyDown := ListKeyDown;
end;


procedure TKMDropList.ListShow(Sender: TObject);
begin
  inherited;
  if ListVisible or (Count < 1) then Exit;

  //Make sure the selected item is visible when list is opened
  if (ItemIndex <> -1) then
  begin
    if InRange(ItemIndex, fListTopIndex, fListTopIndex + fList.GetVisibleRows) then //Try to open list at previously saved scroll position
      fList.TopIndex := fListTopIndex
    else
      fList.TopIndex := ItemIndex;
  end;

  fList.Show;
end;


procedure TKMDropList.ListClick(Sender: TObject);
begin
  fCaption := fList.Item[ItemIndex];

  inherited;
end;


procedure TKMDropList.ListChange(Sender: TObject);
begin
  fCaption := fList.Item[ItemIndex];

  inherited;
end;


procedure TKMDropList.ListHide(Sender: TObject);
begin
  fListTopIndex := fList.TopIndex; //Save list scroll position
  inherited;
  fList.Hide;
end;


function TKMDropList.ListVisible: Boolean;
begin
  Result := fList.Visible;
end;


function TKMDropList.GetItemIndex: Smallint;
begin
  Result := fList.ItemIndex;
end;


procedure TKMDropList.SetItemIndex(aIndex: Smallint);
begin
  fList.ItemIndex := aIndex;
  if aIndex <> -1 then
    fCaption := fList.Item[fList.ItemIndex]
  else
    fCaption := fDefaultCaption;
end;


procedure TKMDropList.SetEnabled(aValue: Boolean);
begin
  inherited;
  fList.Enabled := aValue;
  if not aValue and fList.Visible then
    ListHide(nil);
end;


procedure TKMDropList.SetVisible(aValue: Boolean);
begin
  inherited;
  if not aValue then ListHide(Self);
end;


function TKMDropList.Count: Integer;
begin
  Result := fList.Count;
end;


// When new items are added to the list we must update the drop height and position
procedure TKMDropList.UpdateDropPosition;
begin
  if Count > 0 then
  begin
    fList.Height := Math.min(fDropCount, fList.Count) * fList.ItemHeight + fList.SeparatorsCount*fList.SeparatorHeight;

    if fDropUp then
      fList.AbsTop := AbsTop - fList.Height
    else
      fList.AbsTop := AbsTop + Height;

    fList.Left := AbsLeft - MasterParent.AbsLeft;
  end;
end;


procedure TKMDropList.Add(const aItem: UnicodeString; aTag: Integer = 0);
begin
  fList.Add(aItem, aTag);
end;


procedure TKMDropList.SelectByName(const aText: UnicodeString);
var I: Integer;
begin
  fList.ItemIndex := -1;
  for I := 0 to fList.Count - 1 do
    if fList.Item[I] = aText then
      SetItemIndex(I);
end;


procedure TKMDropList.SelectByTag(aTag: Integer);
var I: Integer;
begin
  fList.ItemIndex := -1;
  for I := 0 to fList.Count - 1 do
    if fList.ItemTags[I] = aTag then
      SetItemIndex(I);
end;


function TKMDropList.GetTag(aIndex: Integer): Integer;
begin
  Result := fList.ItemTags[aIndex];
end;


function TKMDropList.GetSelectedTag: Integer;
begin
  Result := GetTag(fList.fItemIndex);
end;


function TKMDropList.GetItem(aIndex: Integer): UnicodeString;
begin
  Result := fList.Item[aIndex];
end;


procedure TKMDropList.Clear;
begin
  fList.Clear;
end;


procedure TKMDropList.Paint;
var Col: TColor4;
begin
  inherited;

  if fEnabled then Col:=$FFFFFFFF else Col:=$FF888888;
  TKMRenderUI.WriteText(AbsLeft+4, AbsTop+4, Width-8, fCaption, fFont, taLeft, Col);
end;


{ TKMDropColumns }
constructor TKMDropColumns.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer; aFont: TKMFont; const aDefaultCaption: UnicodeString; aStyle: TKMButtonStyle; aShowHeader: Boolean = True);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight, aFont, aStyle);

  fListTopIndex := 0;

  fDefaultCaption := aDefaultCaption;

  fList := TKMColumnBox.Create(MasterParent, 0, 0, aWidth, 0, fFont, aStyle);
  fList.BackAlpha := 0.85;
  fList.OnClick := ListClick;
  fList.OnChange := ListChange;
  fList.ShowHeader := aShowHeader;

  DropWidth := aWidth;

  ListHide(nil);
  fList.OnKeyDown := ListKeyDown;
end;


procedure TKMDropColumns.ListShow(Sender: TObject);
begin
  inherited;
  if ListVisible or (Count < 1) then Exit;

  //Make sure the selected item is visible when list is opened
  if (ItemIndex <> -1) then
  begin
    if InRange(ItemIndex, fListTopIndex, fListTopIndex + fList.GetVisibleRows) then //Try to open list at previously saved scroll position
      fList.TopIndex := fListTopIndex
    else
      fList.TopIndex := ItemIndex;
  end;

  fList.Show;
end;


procedure TKMDropColumns.ListClick(Sender: TObject);
begin
  inherited;
end;


procedure TKMDropColumns.ListChange(Sender: TObject);
begin
  inherited;
end;


procedure TKMDropColumns.ListHide(Sender: TObject);
begin
  fListTopIndex := fList.TopIndex; //Save list scroll position
  inherited;
  fList.Hide;
end;


function TKMDropColumns.ListVisible: Boolean;
begin
  Result := fList.Visible;
end;


function TKMDropColumns.GetItemIndex: smallint;
begin
  Result := fList.ItemIndex;
end;


procedure TKMDropColumns.SetItemIndex(aIndex: smallint);
begin
  fList.ItemIndex := aIndex;
end;


procedure TKMDropColumns.SetDropWidth(aDropWidth: Integer);
begin
  fDropWidth := aDropWidth;
  fList.AbsLeft := AbsLeft + Width - aDropWidth;
  fList.Width := aDropWidth;
end;


procedure TKMDropColumns.SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word);
var ColumnsToShowWhenListHidden: array of Boolean;
    I: Integer;
begin
  SetLength(ColumnsToShowWhenListHidden, Length(aColumns));
  for I := Low(ColumnsToShowWhenListHidden) to High(ColumnsToShowWhenListHidden) do
    ColumnsToShowWhenListHidden[I] := True; // by default show all columns
  SetColumns(aFont, aColumns, aColumnOffsets, ColumnsToShowWhenListHidden);
end;


procedure TKMDropColumns.SetColumns(aFont: TKMFont; aColumns: array of string; aColumnOffsets: array of Word; aColumnsToShowWhenListHidden: array of Boolean);
var I: Integer;
begin
  Assert(Length(aColumns) = Length(aColumnsToShowWhenListHidden));
  fList.SetColumns(aFont, aColumns, aColumnOffsets);
  SetLength(fColumnsToShowWhenListHidden, Length(aColumnsToShowWhenListHidden));
  for I := Low(aColumnsToShowWhenListHidden) to High(aColumnsToShowWhenListHidden) do
    fColumnsToShowWhenListHidden[I] := aColumnsToShowWhenListHidden[I];
end;


procedure TKMDropColumns.SetEnabled(aValue: Boolean);
begin
  inherited;
  fList.Enabled := aValue;
end;


procedure TKMDropColumns.SetVisible(aValue: Boolean);
begin
  inherited;
  if not aValue then ListHide(Self);
end;


function TKMDropColumns.Count: Integer;
begin
  Result := fList.RowCount;
end;


//When new items are added to the list we must update the drop height and position
procedure TKMDropColumns.UpdateDropPosition;
begin
  if Count > 0 then
  begin
    fList.Height := Math.min(fDropCount, fList.RowCount) * fList.ItemHeight + fList.Header.Height * Ord(fList.ShowHeader);

    if fDropUp then
      fList.AbsTop := AbsTop - fList.Height
    else
      fList.AbsTop := AbsTop + Height;

    fList.Left := AbsLeft + Width - DropWidth - MasterParent.AbsLeft;
  end;
end;


procedure TKMDropColumns.Add(aItem: TKMListRow);
begin
  fList.AddItem(aItem);
end;


function TKMDropColumns.GetItem(aIndex: Integer): TKMListRow;
begin
  Result := fList.Rows[aIndex];
end;


procedure TKMDropColumns.Clear;
begin
  fList.Clear;
end;


procedure TKMDropColumns.Paint;
var Col: TColor4;
begin
  inherited;

  if fEnabled then Col:=$FFFFFFFF else Col:=$FF888888;

  if ItemIndex <> -1 then
    fList.DoPaintLine(ItemIndex, AbsLeft, AbsTop, Width - fButton.Width, fColumnsToShowWhenListHidden, False)
  else
    TKMRenderUI.WriteText(AbsLeft + 4, AbsTop + 4, Width - 8 - fButton.Width, fDefaultCaption, fFont, taLeft, Col);
end;


{ TKMDropColorBox }
constructor TKMDropColors.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight,aCount: Integer);
var
  MP: TKMPanel;
  Size: Integer;
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fColorIndex := 0;
  fRandomCaption := ''; //Disable random by default
  fOnClick := ListShow; //It's common behavior when click on dropbox will show the list

  fButton := TKMButton.Create(aParent, aLeft+aWidth-aHeight, aTop, aHeight, aHeight, 5, rxGui, bsMenu);
  fButton.fOnClick := ListShow;
  fButton.MakesSound := false;

  MP := MasterParent;
  fShape := TKMShape.Create(MP, 0, 0, MP.Width, MP.Height);
  fShape.fOnClick := ListHide;

  Size := Round(Sqrt(aCount)+0.5); //Round up

  fSwatch := TKMColorSwatch.Create(MP, 0, 0, Size, Size, aWidth div Size);
  fSwatch.BackAlpha := 0.75;
  fSwatch.fOnClick := ListClick;

  ListHide(nil);
end;


procedure TKMDropColors.ListShow(Sender: TObject);
begin
  if fSwatch.Visible then
  begin
    ListHide(nil);
    Exit;
  end;

  fSwatch.Show;
  fShape.Show;
end;


procedure TKMDropColors.ListClick(Sender: TObject);
begin
  fColorIndex := fSwatch.ColorIndex;
  if Assigned(fOnChange) then fOnChange(Self);
  ListHide(nil);
end;


procedure TKMDropColors.ListHide(Sender: TObject);
begin
  fSwatch.Hide;
  fShape.Hide;
end;


procedure TKMDropColors.SetEnabled(aValue: Boolean);
begin
  inherited;
  fButton.Enabled := aValue;
  fSwatch.Enabled := aValue;
end;


//Set ColorIndex to fSwatch as well since it holds the actual color that we use on Paint
procedure TKMDropColors.SetColorIndex(aIndex: Integer);
begin
  fColorIndex := aIndex;
  fSwatch.ColorIndex := aIndex;
end;


procedure TKMDropColors.UpdateDropPosition;
begin
  fSwatch.Left := AbsLeft;
  fSwatch.Top := AbsTop + Height;
end;


procedure TKMDropColors.SetColors(const aColors: array of TColor4; const aRandomCaption: UnicodeString = '');
begin
  //Store local copy of flag to substitute 0 color with "Random" text
  fRandomCaption := aRandomCaption;
  fSwatch.SetColors(aColors, (fRandomCaption <> ''));
end;


procedure TKMDropColors.Paint;
var
  Col: TColor4;
begin
  inherited;

  UpdateDropPosition;

  TKMRenderUI.WriteBevel(AbsLeft, AbsTop, Width-fButton.Width, Height);
  TKMRenderUI.WriteShape(AbsLeft+2, AbsTop+1, Width-fButton.Width-3, Height-2, fSwatch.GetColor);

  if (fRandomCaption <> '') and (fSwatch.ColorIndex = 0) then
  begin
    if fEnabled then Col:=$FFFFFFFF else Col:=$FF888888;
    TKMRenderUI.WriteText(AbsLeft+4, AbsTop+3, 0, fRandomCaption, fnt_Metal, taLeft, Col);
  end;
end;


{ TKMMinimap }
constructor TKMMinimapView.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  //Radius of circle around player location
  fLocRad := 8;
end;


procedure TKMMinimapView.SetMinimap(aMinimap: TKMMinimap);
begin
  fMinimap := aMinimap;

  if fMinimap.MapX > fMinimap.MapY then
  begin
    fPaintWidth := Width;
    fPaintHeight := Round(Height * fMinimap.MapY / Max(fMinimap.MapX, 1)); // X could = 0
    fLeftOffset := 0;
    fTopOffset := (Height - fPaintHeight) div 2;
  end
  else
  begin
    fPaintWidth := Round(Width * fMinimap.MapX / Max(fMinimap.MapY, 1)); // Y could = 0
    fPaintHeight := Height;
    fLeftOffset := (Width - fPaintWidth) div 2;
    fTopOffset := 0;
  end;
end;


procedure TKMMinimapView.SetViewport(aViewport: TKMViewport);
begin
  fView := aViewport;
end;


function TKMMinimapView.LocalToMapCoords(X,Y: Integer): TKMPoint;
begin
  Result.X := EnsureRange(Trunc((X - AbsLeft - fLeftOffset) * (fMinimap.MapX + 1) / fPaintWidth),  1, fMinimap.MapX);
  Result.Y := EnsureRange(Trunc((Y - AbsTop  - fTopOffset ) * (fMinimap.MapY + 1) / fPaintHeight), 1, fMinimap.MapY);
end;


function TKMMinimapView.MapCoordsToLocal(X,Y: Single; const Inset: ShortInt = 0): TKMPoint;
begin
  Assert(Inset >= -1, 'Min allowed inset is -1, to be within TKMPoint range of 0..n');
  Result.X := AbsLeft + fLeftOffset + EnsureRange(Round(X * fPaintWidth /  fMinimap.MapX), Inset, fPaintWidth  - Inset);
  Result.Y := AbsTop  + fTopOffset  + EnsureRange(Round(Y * fPaintHeight / fMinimap.MapY), Inset, fPaintHeight - Inset);
end;


procedure TKMMinimapView.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;

  MouseMove(X,Y,Shift);
end;


procedure TKMMinimapView.MouseMove(X,Y: Integer; Shift: TShiftState);
var ViewPos: TKMPoint;
begin
  inherited;

  if (ssLeft in Shift) and not fClickableOnce then
  begin
    ViewPos := LocalToMapCoords(X,Y);
    if Assigned(fOnChange) then
      fOnChange(Self, ViewPos.X, ViewPos.Y);
  end;
end;


procedure TKMMinimapView.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
var
  ViewPos: TKMPoint;
  I: Integer;
  T: TKMPoint;
begin
  inherited;

  if fClickableOnce then
  begin
    fClickableOnce := False; //Not clickable anymore
    ViewPos := LocalToMapCoords(X,Y);
    if Assigned(fOnMinimapClick) then
      fOnMinimapClick(Self, ViewPos.X, ViewPos.Y);
  end;

  if fShowLocs then
  for I := 0 to MAX_HANDS - 1 do
  if fMinimap.HandShow[I] and not KMSamePoint(fMinimap.HandLocs[I], KMPOINT_ZERO) then
  begin
    T := MapCoordsToLocal(fMinimap.HandLocs[I].X, fMinimap.HandLocs[I].Y, fLocRad);
    if Sqr(T.X - X) + Sqr(T.Y - Y) < Sqr(fLocRad) then
    begin
      if Assigned(OnLocClick) then
        OnLocClick(I);

      //Do not repeat events for stacked locations
      Break;
    end;
  end;
end;


procedure TKMMinimapView.Paint;
const
  ALERT_RAD = 4;
var
  I,K: Integer;
  R: TKMRect;
  T, T1, T2: TKMPoint;
begin
  inherited;

  if (fMinimap = nil) or (fMinimap.MapX * fMinimap.MapY = 0) then
    Exit;

  if (fMinimap.MapTex.Tex <> 0) then
    TKMRenderUI.WriteTexture(AbsLeft + fLeftOffset, AbsTop + fTopOffset, fPaintWidth, fPaintHeight, fMinimap.MapTex, $FFFFFFFF)
  else
    TKMRenderUI.WriteBevel(AbsLeft, AbsTop, fWidth, fHeight);

  //Alerts (under viewport rectangle)
  if (fMinimap.Alerts <> nil) then
  for I := 0 to fMinimap.Alerts.Count - 1 do
  if fMinimap.Alerts[I].VisibleMinimap then
  begin
    T := MapCoordsToLocal(fMinimap.Alerts[I].Loc.X, fMinimap.Alerts[I].Loc.Y, ALERT_RAD);
    TKMRenderUI.WritePicture(T.X, T.Y, 0, 0, [],
                             fMinimap.Alerts[I].TexMinimap.RX, fMinimap.Alerts[I].TexMinimap.ID,
                             True, fMinimap.Alerts[I].TeamColor, Abs((TimeGet mod 1000) / 500 - 1));
  end;

  //Viewport rectangle
  if fView <> nil then
  begin
    R := fView.GetMinimapClip;
    if (R.Right - R.Left) * (R.Bottom - R.Top) > 0 then
      TKMRenderUI.WriteOutline(AbsLeft + fLeftOffset + Round((R.Left - 1)*fPaintWidth / fMinimap.MapX),
                               AbsTop  + fTopOffset  + Round((R.Top - 1)*fPaintHeight / fMinimap.MapY),
                               Round((R.Right - R.Left)*fPaintWidth / fMinimap.MapX),
                               Round((R.Bottom - R.Top + 1)*fPaintHeight / fMinimap.MapY), 1, $FFFFFFFF);
  end;

  if fShowLocs then
  begin
    //Connect allied players
    for I := 0 to MAX_HANDS - 1 do
    if fMinimap.HandShow[I] and not KMSamePoint(fMinimap.HandLocs[I], KMPOINT_ZERO) then
      for K := I + 1 to MAX_HANDS - 1 do
      if fMinimap.HandShow[K] and not KMSamePoint(fMinimap.HandLocs[K], KMPOINT_ZERO) then
        if (fMinimap.HandTeam[I] <> 0) and (fMinimap.HandTeam[I] = fMinimap.HandTeam[K]) then
        begin
          T1 := MapCoordsToLocal(fMinimap.HandLocs[I].X, fMinimap.HandLocs[I].Y, fLocRad);
          T2 := MapCoordsToLocal(fMinimap.HandLocs[K].X, fMinimap.HandLocs[K].Y, fLocRad);
          TKMRenderUI.WriteLine(T1.X, T1.Y, T2.X, T2.Y, $FFFFFFFF);
        end;

    //Draw all the circles, THEN all the numbers so the numbers are not covered by circles when they are close
    for I := 0 to MAX_HANDS - 1 do
    if fMinimap.HandShow[I] and not KMSamePoint(fMinimap.HandLocs[I], KMPOINT_ZERO) then
    begin
      T := MapCoordsToLocal(fMinimap.HandLocs[I].X, fMinimap.HandLocs[I].Y, fLocRad);
      TKMRenderUI.WriteCircle(T.X, T.Y, fLocRad, fMinimap.HandColors[I]);
    end;

    for I := 0 to MAX_HANDS - 1 do
    if fMinimap.HandShow[I] and not KMSamePoint(fMinimap.HandLocs[I], KMPOINT_ZERO) then
    begin
      T := MapCoordsToLocal(fMinimap.HandLocs[I].X, fMinimap.HandLocs[I].Y, fLocRad);
      TKMRenderUI.WriteText(T.X, T.Y - 6, 0, IntToStr(I+1), fnt_Outline, taCenter);
    end;
  end;

  if not fEnabled then
    TKMRenderUI.WriteBevel(AbsLeft, AbsTop, fWidth+1, fHeight+1, 0, 0.5);
end;


{ TKMDragger }
constructor TKMDragger.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  //Original position is used to resrict movement
  fPositionX := 0;
  fPositionY := 0;
end;


procedure TKMDragger.SetBounds(aMinusX, aMinusY, aPlusX, aPlusY: Integer);
begin
  fMinusX := aMinusX;
  fMinusY := aMinusY;
  fPlusX  := aPlusX;
  fPlusY  := aPlusY;
end;


procedure TKMDragger.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  fStartDragX := X - fPositionX;
  fStartDragY := Y - fPositionY;

  MouseMove(X,Y,Shift);
end;


procedure TKMDragger.MouseMove(X,Y: Integer; Shift: TShiftState);
begin
  inherited;

  if csDown in State then
  begin
    //Bounds are signed numbers, set them properly
    fPositionX := EnsureRange((X - fStartDragX), fMinusX, fPlusX);
    fPositionY := EnsureRange((Y - fStartDragY), fMinusY, fPlusY);

    if Assigned(OnMove) then OnMove(Self, fPositionX, fPositionY);
  end;
end;


procedure TKMDragger.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  inherited;
  MouseMove(X,Y,Shift);
end;


procedure TKMDragger.Paint;
var
  StateSet: TKMButtonStateSet;
begin
  inherited;
  StateSet := [];
  if (csOver in State) and fEnabled then
    StateSet := StateSet + [bsOver];
  if (csDown in State) then
    StateSet := StateSet + [bsDown];
  if not fEnabled then
    StateSet := StateSet + [bsDisabled];

  TKMRenderUI.Write3DButton(AbsLeft, AbsTop, Width, Height, rxGui, 0, $FFFF00FF, StateSet, bsGame);
end;


{ TKMChart }
constructor TKMChart.Create(aParent: TKMPanel; aLeft, aTop, aWidth, aHeight: Integer);
begin
  inherited Create(aParent, aLeft, aTop, aWidth, aHeight);

  fSeparatorPositions := TXStringList.Create;
  fSeparatorPositions.Sorted := True; // Better we have separators sorted

  fFont := fnt_Outline;
  fItemHeight := 20;
  fLineOver := -1;
  fLegendWidth := 150;
  fSeparatorColor := clChartSeparator;
  fSeparatorHeight := 10;
end;


destructor TKMChart.Destroy;
begin
  FreeAndNil(fSeparatorPositions);
  inherited;
end;


procedure TKMChart.AddLine(const aTitle: UnicodeString; aColor: TColor4; const aValues: TKMCardinalArray; aTag: Integer = -1);
begin
  if fMaxLength = 0 then Exit;

  //Make sure there is enough Values to copy to local storage with Move procedure
  Assert(Length(aValues) >= fMaxLength);

  SetLength(fLines, fCount + 1);

  fLines[fCount].Color := aColor;
  fLines[fCount].Title := aTitle;
  fLines[fCount].Tag := aTag;
  fLines[fCount].Visible := True;
  SetLength(fLines[fCount].Values, fMaxLength);
  if SizeOf(aValues) <> 0 then
    Move(aValues[0], fLines[fCount].Values[0], SizeOf(aValues[0]) * fMaxLength);
  Inc(fCount);

  UpdateMaxValue;
end;


function TKMChart.GetSeparatorPos(aIndex: Integer): Integer;
begin
  Result := -1;
  if not InRange(aIndex, 0, fSeparatorPositions.Count - 1) then Exit;

  Result := StrToInt(fSeparatorPositions[aIndex]);
end;


//function TKMChart.GetSeparatorsHeight(aIndex: Integer): Integer;
//var
//  I, Pos: Integer;
//begin
//  Result := 0;
//  for I := 0 to fSeparatorPositions.Count - 1 do
//  begin
//    Pos := SeparatorPos[I];
//    if (Pos <> -1) and (Pos <= aIndex) then
//      Inc(Result, fSeparatorHeight);
//  end;
//end;


procedure TKMChart.AddSeparator(aPosition: Integer);
begin
  fSeparatorPositions.Add(IntToStr(aPosition));
end;


procedure TKMChart.SetSeparatorPositions(aSeparatorPositions: TStringList);
begin
  fSeparatorPositions.Clear;
  fSeparatorPositions.AddStrings(aSeparatorPositions);
end;


//Add alternative values line (e.g. wares count vs. wares produced)
procedure TKMChart.AddAltLine(const aAltValues: TKMCardinalArray);
begin
  Assert(Length(aAltValues) >= fMaxLength);

  SetLength(fLines[fCount-1].ValuesAlt, fMaxLength);
  if SizeOf(aAltValues) <> 0 then
    Move(aAltValues[0], fLines[fCount-1].ValuesAlt[0], SizeOf(aAltValues[0]) * fMaxLength);

  UpdateMaxValue;
end;


//Trims the graph until 5% before the first variation
procedure TKMChart.TrimToFirstVariation;
var
  I, K, FirstVarSample: Integer;
  StartVal: Cardinal;
begin
  FirstVarSample := -1;
  for I:=0 to fCount-1 do
    if Length(fLines[I].Values) > 0 then
    begin
      StartVal := fLines[I].Values[0];
      for K:=1 to Length(fLines[I].Values)-1 do
        if fLines[I].Values[K] <> StartVal then
        begin
          if (K < FirstVarSample) or (FirstVarSample = -1) then
            FirstVarSample := K - 1;
          Break;
        end;
    end;
  if FirstVarSample <= 0 then
  begin
    fMinTime := 0; //No variation at all, so don't trim it (but clear previous value)
    Exit;
  end;
  //Take 5% before the first varied sample
  FirstVarSample := Max(0, FirstVarSample - Max(1, Round(0.05*(fMaxLength - FirstVarSample))));
  //Trim all fLines[I].Values to start at FirstVarSample
  for I := 0 to fCount - 1 do
  begin
    Move(fLines[I].Values[FirstVarSample], fLines[I].Values[0], (Length(fLines[I].Values)-FirstVarSample)*SizeOf(fLines[I].Values[0]));
    SetLength(fLines[I].Values, Length(fLines[I].Values)-FirstVarSample);
  end;
  //Set start time so the horizontal time ticks are rendered correctly
  fMinTime := Round((FirstVarSample/fMaxLength) * fMaxTime);
  //All lines have now been trimmed, so update fMaxLength
  fMaxLength := fMaxLength - FirstVarSample;
end;


procedure TKMChart.Clear;
begin
  fCount := 0;
  SetLength(fLines, 0);
  fMaxValue := 0;
  ClearSeparators;
end;


procedure TKMChart.ClearSeparators;
begin
  fSeparatorPositions.Clear;
end;


procedure TKMChart.SetLineVisible(aLineID: Integer; aVisible: Boolean);
begin
  fLines[aLineID].Visible := aVisible;
  UpdateMaxValue;
end;


procedure TKMChart.UpdateMaxValue;
var I, K: Integer;
begin
  fMaxValue := 0;
  for I := 0 to fCount - 1 do
    if fLines[I].Visible then
      for K := 0 to fMaxLength - 1 do
        if fLines[I].Values[K] > fMaxValue then
          fMaxValue := fLines[I].Values[K];
end;


function TKMChart.GetLine(aIndex: Integer): TKMGraphLine;
begin
  Result := fLines[aIndex];
end;


function TKMChart.GetLineNumber(aY: Integer): Integer;
var
  I, S, LineTop, LienBottom: Integer;
begin
  Result := -1;
  S := 0;
  LineTop := AbsTop + 5 + 20*Byte(fLegendCaption <> '');
  for I := 0 to fCount - 1 do
  begin
    if SeparatorPos[S] = I then
    begin
      Inc(LineTop, fSeparatorHeight);
      Inc(S);
    end;
    LienBottom := LineTop + fItemHeight;
    if InRange(aY, LineTop, LienBottom) then
    begin
      Result := I;
      Exit;
    end;
    LineTop := LienBottom;
  end;
end;


procedure TKMChart.MouseMove(X, Y: Integer; Shift: TShiftState);
begin
  inherited;

  fLineOver := -1;
  if X < AbsLeft + Width - fLegendWidth + 5 then Exit;
  fLineOver := GetLineNumber(Y);
end;


procedure TKMChart.MouseUp(X, Y: Integer; Shift: TShiftState; Button: TMouseButton);
var I: Integer;
begin
  inherited;

  if X < AbsLeft + Width - fLegendWidth+5 then Exit;

  I := GetLineNumber(Y);
  if not InRange(I, 0, fCount - 1) then Exit;

  fLines[I].Visible := not fLines[I].Visible;

  UpdateMaxValue;
end;


procedure TKMChart.Paint;
const
  IntervalCount: array [0..9] of Word = (1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000);
  IntervalTime: array [0..10] of Word = (30, 1*60, 5*60, 10*60, 15*60, 30*60, 1*60*60, 2*60*60, 3*60*60, 4*60*60, 5*60*60);

var
  G: TKMRect;
  TopValue: Integer;

  procedure PaintAxisLabel(aTime: Integer; aIsPT: Boolean = False);
  var
    XPos: Integer;
  begin
    XPos := G.Left + Round((aTime - fMinTime) / (fMaxTime-fMinTime) * (G.Right - G.Left));
    TKMRenderUI.WriteShape(XPos, G.Bottom - 2, 2, 5, IfThen(aIsPT, clChartPeacetimeLn, icWhite));
    TKMRenderUI.WriteText (XPos, G.Bottom + 4, 0, TimeToString(aTime / 24 / 60 / 60), fnt_Game, taLeft, IfThen(aIsPT, clChartPeacetimeLbl, icWhite));
    TKMRenderUI.WriteLine(XPos, G.Top, XPos, G.Bottom, IfThen(aIsPT, clChartPeacetimeLn, clChartDashedVLn), $CCCC);
    if aIsPT then
      TKMRenderUI.WriteText(XPos - 3, G.Bottom + 4, 0, 'PT-', fnt_Game, taRight, clChartPeacetimeLbl); //Todo translate
  end;

  procedure RenderHorizontalAxisTicks;
  var
    I, Best: Integer;
  begin
    //Find first time interval that will have less than 10 ticks
    Best := 0;
    for I := Low(IntervalTime) to High(IntervalTime) do
      if (fMaxTime-fMinTime) div IntervalTime[I] < 7 then
      begin
        Best := IntervalTime[I];
        Break;
      end;

    //Paint time axis labels
    if (Best <> 0) and (fMaxTime <> fMinTime) then
      if (fPeaceTime <> 0) and InRange(fPeaceTime, fMinTime, fMaxTime) then
      begin
        //Labels before PT and PT himself
        for I := 0 to ((fPeaceTime - fMinTime) div Best) do
          PaintAxisLabel(fPeaceTime - I * Best, I = 0);

        //Labels after PT
        for I := 1 to ((fMaxTime - fPeaceTime) div Best) do
          PaintAxisLabel(fPeaceTime + I * Best);
      end else
        for I := Ceil(fMinTime / Best) to (fMaxTime div Best) do
          PaintAxisLabel(I * Best);
  end;

  procedure RenderChartAndLegend;
  const
    MARKS_FONT: TKMFont = fnt_Grey;
  var
    I, S, CheckSize, XPos, YPos, Height: Integer;
    NewColor: TColor4;
  begin
    CheckSize := gRes.Fonts[MARKS_FONT].GetTextSize('v').Y + 1;
    S := 0;
    XPos := G.Right + 10;
    YPos := G.Top + 8 + 20*Byte(fLegendCaption <> '');

    //Legend title and outline
    Height := fItemHeight*fCount + 6 + 20*Byte(fLegendCaption <> '') + fSeparatorPositions.Count*fSeparatorHeight;
    TKMRenderUI.WriteShape(G.Right + 5, G.Top, fLegendWidth, Height, icDarkestGrayTrans);
    TKMRenderUI.WriteOutline(G.Right + 5, G.Top, fLegendWidth, Height, 1, icGray);
    if fLegendCaption <> '' then
      TKMRenderUI.WriteText(G.Right + 5, G.Top + 4, fLegendWidth, fLegendCaption, fnt_Metal, taCenter, icWhite);
    //Charts and legend
    for I := 0 to fCount - 1 do
    begin
      //Adjust the color if it blends with black background
      NewColor := EnsureBrightness(fLines[I].Color, 0.3);

      // If color is similar to highlight color, then use alternative HL color
      if GetColorDistance(NewColor, clChartHighlight) < 0.1 then
        NewColor := clChartHighlight2;

      if (csOver in State) and (I = fLineOver) then
        NewColor := clChartHighlight;

      //Charts
      if fLines[I].Visible then
      begin
        TKMRenderUI.WritePlot(G.Left, G.Top, G.Right-G.Left, G.Bottom-G.Top, fLines[I].Values, TopValue, NewColor, 2);
        if Length(fLines[I].ValuesAlt) > 0 then
          TKMRenderUI.WritePlot(G.Left, G.Top, G.Right-G.Left, G.Bottom-G.Top, fLines[I].ValuesAlt, TopValue, NewColor, 1);
      end;

      if SeparatorPos[S] = I then
      begin
        Inc(YPos, fSeparatorHeight);
        Inc(S);
      end;

      //Checkboxes
      TKMRenderUI.WriteBevel(XPos, YPos, CheckSize - 4, CheckSize - 4, 1, 0.3);
      TKMRenderUI.WriteOutline(XPos, YPos, CheckSize - 4, CheckSize - 4, 1, clChkboxOutline);
      if fLines[I].Visible then
        TKMRenderUI.WriteText(XPos + (CheckSize-4) div 2, YPos - 1, 0, 'v', MARKS_FONT, taCenter, NewColor);

      //Legend
      TKMRenderUI.WriteText(XPos + CheckSize, YPos, 0, fLines[I].Title, fnt_Game, taLeft, NewColor);
      Inc(YPos, fItemHeight);
    end;
  end;

var
  I: Integer;
  Best, Tmp: Integer;
begin
  inherited;

  G := KMRect(AbsLeft + 40, AbsTop, AbsLeft + Width - fLegendWidth, AbsTop + Height - 20);

  //Add margin to MaxValue so that it does not blends with upper border
  TopValue := Max(Round(fMaxValue * 1.1), fMaxValue + 1);

  //Find first interval that will have less than 10 ticks
  Best := 0;
  for I := Low(IntervalCount) to High(IntervalCount) do
    if TopValue div IntervalCount[I] < 10 then
    begin
      Best := IntervalCount[I];
      Break;
    end;

  //Dashed lines in the background
  if Best <> 0 then
    for I := 1 to (TopValue div Best) do
    begin
      Tmp := G.Top + Round((1 - I * Best / TopValue) * (G.Bottom - G.Top));
      TKMRenderUI.WriteText(G.Left - 5, Tmp - 6, 0, IntToStr(I * Best), fnt_Game, taRight);
      TKMRenderUI.WriteLine(G.Left, Tmp, G.Right, Tmp, clChartDashedHLn, $CCCC);
    end;

  //Render horizontal axis ticks
  RenderHorizontalAxisTicks;

  RenderChartAndLegend;

  //Render the highlighted line above all the others and thicker so you can see where it goes under others
  if (csOver in State) and InRange(fLineOver, 0, fCount-1) and fLines[fLineOver].Visible then
    TKMRenderUI.WritePlot(G.Left, G.Top, G.Right-G.Left, G.Bottom-G.Top, fLines[fLineOver].Values, TopValue, clChartHighlight, 3);

  //Outline
  TKMRenderUI.WriteOutline(G.Left, G.Top, G.Right-G.Left, G.Bottom-G.Top, 1, icWhite);

  //Title
  TKMRenderUI.WriteText(G.Left + 5, G.Top + 5, 0, fCaption, fFont, taLeft);

  //Render vertical axis captions
  TKMRenderUI.WriteText(G.Left - 5, G.Bottom - 6, 0, IntToStr(0), fnt_Game, taRight);
  //TKMRenderUI.WriteText(Left+20, Top + 20, 0, 0, IntToStr(fMaxValue), fnt_Game, taRight);

end;


{ TKMMasterControl }
destructor TKMMasterControl.Destroy;
begin
  fMasterPanel.Free; //Will destroy all its childs as well

  inherited;
end;


procedure TKMMasterControl.SetCtrlDown(aCtrl: TKMControl);
begin
  if fCtrlDown <> nil then
    fCtrlDown.State := fCtrlDown.State - [csDown]; //Release previous

  if aCtrl <> nil then
    aCtrl.State := aCtrl.State + [csDown];         //Press new

  fCtrlDown := aCtrl;                              //Update info
end;


procedure TKMMasterControl.SetCtrlFocus(aCtrl: TKMControl);
begin
  if fCtrlFocus <> nil then
    fCtrlFocus.State := fCtrlFocus.State - [csFocus];

  if aCtrl <> nil then
    aCtrl.State := aCtrl.State + [csFocus];

  if aCtrl <> fCtrlFocus then
  begin
    if fCtrlFocus <> nil then
    begin
      fCtrlFocus.FocusChanged(False);
      if  Assigned(fCtrlFocus.fOnFocus) then
        fCtrlFocus.fOnFocus(False);
      // Reset Parent Panel FocusedControlIndex only for different parents
      if (aCtrl = nil) or (aCtrl.Parent <> fCtrlFocus.Parent) then
        fCtrlFocus.Parent.ResetFocusedControlIndex;
    end;

    if aCtrl <> nil then
    begin
      aCtrl.FocusChanged(True);
      if Assigned(aCtrl.fOnFocus) then
        aCtrl.fOnFocus(True);
      aCtrl.Parent.FocusedControlIndex := aCtrl.ControlIndex; //Set Parent Panel FocusedControlIndex to new focused control
    end;
  end;

  fCtrlFocus := aCtrl;
end;


procedure TKMMasterControl.SetCtrlOver(aCtrl: TKMControl);
begin
  if fCtrlOver <> nil then fCtrlOver.State := fCtrlOver.State - [csOver];
  if aCtrl <> nil then aCtrl.State := aCtrl.State + [csOver];
  fCtrlOver := aCtrl;
end;


procedure TKMMasterControl.SetCtrlUp(aCtrl: TKMControl);
begin
  fCtrlUp := aCtrl;
  //Give focus only to controls with Focusable=True
  if (fCtrlUp <> nil) and fCtrlUp.Focusable then
    if fCtrlDown = fCtrlUp then
      CtrlFocus := fCtrlUp
    else
      CtrlFocus := nil;
end;


//Check If Control if it is allowed to be focused on (manual or automatically)
function TKMMasterControl.IsFocusAllowed(aCtrl: TKMControl): Boolean;
begin
  Result := aCtrl.fVisible
        and aCtrl.Enabled
        and aCtrl.Focusable
        and not IsCtrlCovered(aCtrl); // Do not allow to focus on covered Controls
end;


//Check If Control if it is allowed to be automatically (not manual, by user) focused on
function TKMMasterControl.IsAutoFocusAllowed(aCtrl: TKMControl): Boolean;
begin
  Result := aCtrl.AutoFocusable and IsFocusAllowed(aCtrl);
end;


function TKMMasterControl.GetNextCtrlID: Integer;
begin
  Inc(fControlIDCounter);
  Result := fControlIDCounter;
end;


//Update focused control
procedure TKMMasterControl.UpdateFocus(aSender: TKMControl);
  function FindFocusable(C: TKMPanel): Boolean;
  var I: Integer;
      Ctrl: TKMControl;
  begin
    Result := False;
    Ctrl := C.FindFocusableControl(False);
    if Ctrl <> nil then
    begin
      CtrlFocus := Ctrl;
      Result := True;
      Exit;
    end;

    for I := 0 to C.ChildCount - 1 do
      if C.Childs[I].fVisible
        and C.Childs[I].Enabled
        and (C.Childs[I] is TKMPanel) then
      begin
        Result := FindFocusable(TKMPanel(C.Childs[I]));
        if Result then Exit;
      end;
  end;
begin
  if aSender.Visible and aSender.Enabled
    and ((not (aSender is TKMPanel) and aSender.Focusable) or (aSender is TKMPanel)) then
  begin
    // Something showed up or became enabled

    // If something showed up - focus on it
    if not (aSender is TKMPanel) and aSender.Focusable then
      CtrlFocus := aSender;
    // If panel showed up - try to focus on its contents
    if aSender is TKMPanel then
      FindFocusable(TKMPanel(aSender));
  end else
  begin
    // Something went hidden or disabled
    if (CtrlFocus = nil) or not CtrlFocus.Visible or not CtrlFocus.Enabled or not CtrlFocus.Focusable then
    begin
      // If there was no focus, or it is our Focus control that went hidden or disabled
      CtrlFocus := nil;
      FindFocusable(fMasterPanel);
    end;
  end;
end;


procedure TKMMasterControl.UpdateState(aTickCount: Cardinal);
begin
  fMasterPanel.UpdateState(aTickCount);
end;


//Check if control is covered by other controls or not
//We assume that control is covered if any of his 4 corners is covered
//For corners used actual corners with 1 px offset inside to solve border collisions
//Use Self coordinates to check, because some controls can contain other sub-controls (f.e. TKMNumericEdit)
function TKMMasterControl.IsCtrlCovered(aCtrl: TKMControl): Boolean;
begin
  Result := (HitControl(aCtrl.SelfAbsLeft + 1, aCtrl.SelfAbsTop + 1) <> aCtrl)
        or (HitControl(aCtrl.SelfAbsLeft + aCtrl.SelfWidth - 1, aCtrl.SelfAbsTop + 1) <> aCtrl)
        or (HitControl(aCtrl.SelfAbsLeft + 1, aCtrl.SelfAbsTop + aCtrl.SelfHeight - 1) <> aCtrl)
        or (HitControl(aCtrl.SelfAbsLeft + aCtrl.SelfWidth - 1, aCtrl.SelfAbsTop + aCtrl.SelfHeight - 1) <> aCtrl);
end;


{ Recursing function to find topmost control (excl. Panels)}
function TKMMasterControl.HitControl(X,Y: Integer; aIncludeDisabled: Boolean = False): TKMControl;
  function ScanChild(P: TKMPanel; aX,aY: Integer): TKMControl;
  var I: Integer;
      Child: TKMControl;
  begin
    Result := nil;
    //Process controls in reverse order since last created are on top
    for I := P.ChildCount - 1 downto 0 do
    begin
      Child := P.Childs[I];
      if Child.fVisible then //If we can't see it, we can't touch it
      begin
        //Scan Panels childs first, if none is hit - hittest the panel
        if (Child is TKMPanel) then
        begin
          Result := ScanChild(TKMPanel(Child),aX,aY);
          if Result <> nil then
            Exit;
        end;
        if Child.HitTest(aX, aY, aIncludeDisabled) then
        begin
          Result := Child;
          Exit;
        end;
      end;
    end;
  end;
begin
  Result := ScanChild(fMasterPanel, X, Y);
end;


function TKMMasterControl.KeyDown(Key: Word; Shift: TShiftState): Boolean;
begin
  //CtrlFocus could be on another menu page and no longer visible
  if (CtrlFocus <> nil) and CtrlFocus.Visible then
    Result := CtrlFocus.KeyDown(Key, Shift)
  else
    Result := false;
end;


procedure TKMMasterControl.KeyPress(Key: Char);
begin
  //CtrlFocus could be on another menu page and no longer visible
  if (CtrlFocus <> nil) and CtrlFocus.Visible then
    CtrlFocus.KeyPress(Key);
end;


function TKMMasterControl.KeyUp(Key: Word; Shift: TShiftState): Boolean;
begin
  //CtrlFocus could be on another menu page and no longer visible
  if (CtrlFocus <> nil) and CtrlFocus.Visible then
    Result := CtrlFocus.KeyUp(Key, Shift)
  else
    Result := false;
end;


procedure TKMMasterControl.MouseDown(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  CtrlDown := HitControl(X,Y);
  fMasterPanel.ControlMouseDown(CtrlDown, Shift);
  if CtrlDown <> nil then
    CtrlDown.MouseDown(X, Y, Shift, Button);
end;


procedure TKMMasterControl.MouseMove(X,Y: Integer; Shift: TShiftState);
var HintControl: TKMControl;
begin
  CtrlOver := HitControl(X,Y);

  //User is dragging some Ctrl (e.g. scrollbar) and went away from Ctrl bounds
  if (CtrlDown <> nil) and CtrlDown.Visible then
    CtrlDown.MouseMove(X, Y, Shift)
  else
  if CtrlOver <> nil then
    CtrlOver.MouseMove(X, Y, Shift);

  //The Game hides cursor when using DirectionSelector, don't spoil it
  if gRes.Cursors.Cursor <> kmc_Invisible then
    if CtrlOver is TKMEdit then
      gRes.Cursors.Cursor := kmc_Edit
    else
    if CtrlOver is TKMDragger then
      gRes.Cursors.Cursor := kmc_DragUp
    else
      if gRes.Cursors.Cursor in [kmc_Edit, kmc_DragUp] then
        gRes.Cursors.Cursor := kmc_Default; //Reset the cursor from these two special cursors

  HintControl := HitControl(X, Y, True); //Include disabled controls
  if (CtrlDown = nil) and (HintControl <> nil) and Assigned(fOnHint) then
    fOnHint(HintControl);
end;


procedure TKMMasterControl.MouseUp(X,Y: Integer; Shift: TShiftState; Button: TMouseButton);
begin
  CtrlUp := HitControl(X,Y);

  //Here comes tricky part, we can't do anything after calling an event (it might Destroy everything,
  //e.g. Exit button, or Resolution change). We need to release CtrlDown (otherwise it remains
  //pressed), but we need to keep csDown state until it's registered by Control.MouseUp
  //to call OnClick. So, we nil fCtrlDown here and Control.MouseUp will reset ControlState
  //Other case, if we don't care for OnClick (CtrlDown<>CtrlUp) - just release the CtrDown as usual
  if CtrlDown <> CtrlUp then
    CtrlDown := nil
  else
    fCtrlDown := nil;

  fMasterPanel.ControlMouseUp(CtrlUp, Shift); // Must be invoked before CtrlUp.MouseUp to avoid problems on game Exit
  if CtrlUp <> nil then
    CtrlUp.MouseUp(X, Y, Shift, Button);

  //Do not place any code here, we could have Exited in OnClick event
end;


procedure TKMMasterControl.MouseWheel(X,Y: Integer; WheelDelta: Integer);
var C: TKMControl;
begin
  C := HitControl(X, Y);
  if C <> nil then C.MouseWheel(C, WheelDelta);
end;


{Paint controls}
{Leave painting of childs to their parent control}
procedure TKMMasterControl.Paint;
begin
  CtrlPaintCount := 0;
  fMasterPanel.Paint;

  if MODE_DESIGN_CONTORLS and (CtrlFocus <> nil) then
    TKMRenderUI.WriteText(CtrlFocus.AbsLeft, CtrlFocus.AbsTop-14, 0, inttostr(CtrlFocus.AbsLeft)+':'+inttostr(CtrlFocus.AbsTop), fnt_Grey, taLeft);
end;


procedure TKMMasterControl.SaveToFile(const aFileName: UnicodeString);
var ft: Textfile;
begin
  AssignFile(ft,aFileName);
  Rewrite(ft);

  //fCtrl.SaveToFile; //Will save all the childs as well, recursively alike Paint or HitControl
  //writeln(ft, ClassName);
  //writeln(ft, Format('[%d %d %d %d]', [fLeft, fTop, fWidth, fHeight]));

  CloseFile(ft);
end;


end.

