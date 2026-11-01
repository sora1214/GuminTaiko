-- 使うクラスを読み込む
require("common.State")


-- このクラス
Panel = {
	m_State = State.New("GameSettingPanel"),
	m_MCName = "panel_mc",
	m_PanelName = {"btntype","sound","net","tutorial","staffroll"},
	m_PanelTitle = {"config_buttontype","config_sound","config_net","config_tutorial","config_staffroll"},
	m_CommentKey = {"config_comment_buttontype","config_comment_sound","config_comment_net","config_comment_tutorial","config_comment_staffroll"},

	m_PanelMc,
	m_PanelParts = {},
	m_PanelPartsOn = {},
	m_PanelPartsOff = {},
	m_PanelPartsCursor = {},
	m_HelpMc,

	m_DecideCursor = 0,

	Init = function(this)

		-- ステートマシンを組み立てておく、実際に実行されるのはステート処理を実行するとき
		-- 開始処理
		this.m_State.Func["Begin"] = function()
			-- ムービークリップ取得
			this.m_PanelMc = Lumen.GetMovieClip("main/panel_mc",true)
			this.m_HelpMc = this.m_PanelMc:GetChildMc("help_mc",true)

			-- パネルの初期化
			-- Luaは配列のインデックス1から
			for index = 1,5 do
				-- ムービークリップ取得
				this.m_PanelParts[index] = this.m_PanelMc:GetChildMc("panel_"..this.m_PanelName[index],true)

				this.m_PanelPartsOn[index] = this.m_PanelParts[index]:GetChildMc("panel_on",true)
				this.m_PanelPartsOff[index] = this.m_PanelParts[index]:GetChildMc("panel_off",true)
				this.m_PanelPartsCursor[index] = this.m_PanelParts[index]:GetChildMc("cursor_decide",true)

				-- 文字列設定
				this.m_PanelParts[index]:SetText("text_title","text_panel",this.m_PanelTitle[index])

				-- 絵柄設定
				this.m_PanelPartsOn[index]:GotoAndStop(this.m_PanelName[index])
				this.m_PanelPartsOff[index]:GotoAndStop(this.m_PanelName[index])

				-- パネルを非アクティブにする
				this:PanelOff(index)
			end

			this.m_State:SetState("BeginWait")
		end
		-- 開始後の待ち
		this.m_State.Func["BeginWait"] = function()
		end
		-- 入り待ち
		this.m_State.Func["IntroWait"] = function()
			if (this.m_PanelMc:IsPlay() == false) then
				this.m_State:SetState("Main")
			end
		end
		-- メイン実行中
		this.m_State.Func["Main"] = function()
		end

		-- 決定カーソル
		this.m_State.Func["DecideActionCursor"] = function()
			if (this.m_PanelPartsCursor[this.m_DecideCursor]:IsPlay() == false) then
				this.m_State:SetState("DecideActionCursorFinish")
			end
		end
		-- 決定カーソル終了
		this.m_State.Func["DecideActionCursorFinish"] = function()
		end

		-- はけ
		this.m_State.Func["OutAction"] = function()
			if (this.m_PanelMc:IsPlay() == false) then
				this.m_State:SetState("OutActionFinish")
			end
		end
		-- はけ終了
		this.m_State.Func["OutActionFinish"] = function()
		end

	end,

	Update = function(this)
		-- ステート処理
		this.m_State:Update()
	end,

	Play = function(this)
		this.m_PanelMc:Play()
	end,

	-- イントロ開始
	IntroStart = function(this)
		-- 開始
		this.m_PanelMc:GotoAndPlay("start_panel")

		this.m_State:SetState("IntroWait")
	end,
	IsFinishIntroAction = function(this)
		if (this.m_State.State == "Main") then
			return true
		end
		return false
	end,

	-- 決定
	DecideCursor = function(this,panelId)
		this.m_DecideCursor = panelId

		this.m_PanelParts[this.m_DecideCursor]:GotoAndStop("decide")
		this.m_PanelPartsCursor[this.m_DecideCursor]:Play()

		this.m_State:SetState("DecideActionCursor")
	end,
	IsFinishDecideCursorAction = function(this)
		if (this.m_State.State == "DecideActionCursorFinish") then
			return true
		end
		return false
	end,

	-- ぱねるはけ
	Out = function(this)
		-- はけ
		this.m_PanelMc:GotoAndPlay("out_panel")

		this.m_State:SetState("OutAction")
	end,
	IsFinishOutAction = function(this)
		if (this.m_State.State == "OutActionFinish") then
			return true
		end
		return false
	end,

	-- パネルのアクティブ化
	PanelOn = function(this,index)
		this.m_PanelParts[index]:GotoAndStop("on")

		this.m_PanelPartsOn[index]:SetVisible(true)
		this.m_PanelPartsOff[index]:SetVisible(false)
	end,
	-- パネルの非アクティブ化
	PanelOff = function(this,index)
		this.m_PanelParts[index]:GotoAndStop("off")

		this.m_PanelPartsOn[index]:SetVisible(false)
		this.m_PanelPartsOff[index]:SetVisible(true)
	end,
	-- パネル切り替え
	ChangePanel = function(this,oldID,newID)
		-- パネルON/OFF
		this:PanelOff(oldID)
		this:PanelOn(newID)
		this:SetHelpMessage(newID)
	end,



	-- ヘルプメッセージ関連
	OpenHelpMessage = function(this)
		this.m_HelpMc:GotoAndPlay("help_start")
	end,
	SetHelpMessage = function(this,panelId)
		this.m_HelpMc:SetText("text_help_02_mc","text_help_02",this.m_CommentKey[panelId])
	end,
	CloseHelpMessage = function(this)
		this.m_HelpMc:GotoAndPlay("help_end")
	end
}
