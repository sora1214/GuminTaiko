require("entry.nameentry_one")

-- ローマ字の対応について
-- あ行：  a       i       u       e       o
-- あ行： xa(ぁ)  xi(ぃ)  xu(ぅ)  xe(ぇ)  xo(ぉ)
-- か行： ka      ki      ku      ke      ko
-- が行： ga      gi      gu      ge      go
-- さ行： sa      si      su      se      so
-- ざ行： za      zi      zu      ze      zo
-- た行： ta      ti      tu      te      to
-- だ行： da      di      du      de      do
-- た行：                xtu(っ)
-- な行： na      ni      nu      ne      no
-- は行： ha      hi      hu      he      ho
-- ば行： ba      bi      bu      be      bo
-- ぱ行： pa      pi      pu      pe      po
-- や行： ya              yu              yo
-- や行：xya(ゃ)         xyu(ゅ)         xyo(ょ)
-- ら行： ra      ri      ru      re      ro
-- わ行： wa      wi(ゐ)          we(ゑ)  wo(を)
-- わ行：xwa(ゎ)
-- ん　： nn
-- 特殊：sp1(～) sp2(ー) sp3(？) sp4(！)
-- 他　：back1 back2 end


-- ネームエントリー
NameEntry = {
	ring1_list_ = {{"a",6},{"k",6},{"s",6},{"t",6},{"n",6},{"h",6},{"m",6},{"y",4},{"r",6},{"w",6},{"sp",5},{"back",0},{"end",0}},
	ring2_list_ = {	{{  "a",3},{  "i",3},{  "u",3},{   "e",3},{   "o",3},{"back",0}},
					{{ "ka",3},{ "ki",3},{ "ku",3},{  "ke",3},{  "ko",3},{"back",0}},
					{{ "sa",3},{ "si",3},{ "su",3},{  "se",3},{  "so",3},{"back",0}},
					{{ "ta",3},{ "ti",3},{ "tu",4},{  "te",3},{  "to",3},{"back",0}},
					{{ "na",0},{ "ni",0},{ "nu",0},{  "ne",0},{  "no",0},{"back",0}},
					{{ "ha",4},{ "hi",4},{ "hu",4},{  "he",4},{  "ho",4},{"back",0}},
					{{ "ma",0},{ "mi",0},{ "mu",0},{  "me",0},{  "mo",0},{"back",0}},
					{{ "ya",3},{ "yu",3},{ "yo",3},{"back",0}},
					{{ "ra",0},{ "ri",0},{ "ru",0},{  "re",0},{  "ro",0},{"back",0}},
					{{ "wa",3},{ "wi",0},{ "we",0},{  "wo",0},{  "nn",0},{"back",0}},
					{{"sp1",0},{"sp2",0},{"sp3",0},{ "sp4",0},{"back",0}},
					},
	ring3_list_ = {	{{      "a", "xa","back"},{      "i", "xi","back"},{      "u", "xu","back"},{      "e","xe","back"},{      "o","xo","back"}},
					{{     "ka", "ga","back"},{     "ki", "gi","back"},{     "ku", "gu","back"},{     "ke","ge","back"},{     "ko","go","back"}},
					{{     "sa", "za","back"},{     "si", "zi","back"},{     "su", "zu","back"},{     "se","ze","back"},{     "so","zo","back"}},
					{{     "ta", "da","back"},{     "ti", "di","back"},{"tu","du","xtu","back"},{     "te","de","back"},{     "to","do","back"}},
					{},
					{{"ha","ba", "pa","back"},{"hi","bi", "pi","back"},{"hu","bu", "pu","back"},{"he","be","pe","back"},{"ho","bo","po","back"}},
					{},
					{{     "ya","xya","back"},{     "yu","xyu","back"},{     "yo","xyo","back"}},
					{},
					{{     "wa","xwa","back"}},
					},

	EnumReturn = {kDoing = 1,kFinish = 2,kUpload = 3},

	Init = function(this,InstanceName)
		this.instance_name_ = InstanceName
	end,
	LoadMovie = function(this)
		Lumen.LoadMovie("lumen/000_default/entry/name_entry",this.instance_name_)
	end,
	-- 初期化
	Setup = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then
			this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)

			this.entrymain_ = {NameEntryOnePlayer.New(this.mc_.nameentry_1p_instance,this.mc_.guide_instance_1,1),NameEntryOnePlayer.New(this.mc_.nameentry_2p_instance,this.mc_.guide_instance_2,2)}
			this.entrymain_[1]:Setup()
			this.entrymain_[2]:Setup()
		end
	end,
	-- 表示ON/OFF
	SetVisible = function(this,flag)
		this.mc_:SetVisible(flag)
	end,
	-- プレイヤー数設定
	SetPlayerNum = function(this,playerNum)
		this.entrymain_[1]:SetPlayerNum(playerNum)
		this.entrymain_[2]:SetPlayerNum(playerNum)
	end,
	-- 開始
	Start = function(this,plIdx)
		this.entrymain_[plIdx]:Start()
	end,
	StartSelect = function(this,plIdx)
		this.entrymain_[plIdx]:StartSelect()
	end,
	-- 処理済みにする
	SetFinish = function(this,plIdx)
		this.entrymain_[plIdx]:SetFinish()
	end,
	-- 再生中？
	IsPlay = function(this,plIdx)
	end,

	-- 更新
	Update = function(this,plIdx,isWaitUpload)
		return this.entrymain_[plIdx]:Update(isWaitUpload)
	end,

	-- 名前を決定する
	DecideName = function(this,plIdx)
		this.entrymain_[plIdx]:DecideName()
	end,

	-- 時間切れ処理
	TimeUp = function(this,plIdx)
		this.entrymain_[plIdx]:TimeUp()
	end,
}
