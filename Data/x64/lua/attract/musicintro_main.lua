-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.Banner")

require("attract.musicintro_songdata")

-- このクラス
MusicIntroMain = {

	-- 変数
	state_ = State.New("MusicIntroMain"),
	banner_ = Banner.New("banner_instance",true,false,GameMode.kEnso),
	nowtime_ = 0,
	one_song_totaltime_ = 5 * Common.FPS,
	song_play_time_ = 4.5 * Common.FPS,
	now_song_id_ = 1,

	load_counter_ = 0,

	song_play_state_ = "Wait",

	-- 初期化関数
	Init = function(this)
		-- メインのステートマシン組み立て
		this.state_.func_["Begin"] = function()
			-- 各種パーツ読み込み
			this.banner_:LoadMovie()

			-- 曲情報組み立て
			this.music_info_ = {}
			this.music_info_sub_ = {}
			this.music_info_sub_enable_ = {}

			for key,value in pairs(MusicIntroIDList) do
				-- 表示曲
				this.music_info_[key] = MusicInfo.create(value.main_uid)

				-- 一緒に表示する曲
				this.music_info_sub_[key] = {}
				this.music_info_sub_enable_[key] = {}

				for idx = 1,4 do
					if(value.sub_uid[idx] == -1) then
						this.music_info_sub_enable_[key][idx] = false
					else
						this.music_info_sub_[key][idx] = MusicInfo.create(value.sub_uid[idx])
						this.music_info_sub_enable_[key][idx] = true
					end
				end
			end

			this.state_:SetState("Loading")
		end
		this.state_.func_["Loading"] = function()
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.musicintro_mc_ = Lumen.GetMovieClip("musicintro_instance",true)

				this.song_info_ = MusicIntroSongData.New(this.musicintro_mc_:GetChildMc("songname_instance",true))
				this.song_info_:Init()

				this.other_song_info_ = {}
				for idx = 0,3 do
					this.other_song_info_[(idx + 1)] = {}
					this.other_song_info_[(idx + 1)] = MusicIntroSongData.New(this.musicintro_mc_:GetChildMc("songnamesame_instance_"..idx,true))
					this.other_song_info_[(idx + 1)]:Init()
				end

				-- 一曲目の設定
				this:DispMusicInfo()

				-- テキスト表示
				this.musicintro_mc_:SetText("othersong_text_instance","text_othersongs","attract_othersongs")

				-- バナーの準備
				this.banner_:Setup()
				this.banner_:Start()

				-- C側に準備完了通知
				Common.LuaPrepareFinish()

				this.state_:SetState("FadeInWait")
			end
		end
		this.state_.func_["FadeInWait"] = function()
			if(FadeFlag == false) then
				-- 曲の再生
				this:PlaySound()

				-- ここからカードタッチ有効
				local card_status = BanaPass.GetCardTouchStatus()
				if((card_status == GameConnectStatus.kSuccess) or (card_status == GameConnectStatus.kError)) then
				else
					BanaPass.StartCardTouch()
				end
				-- ここからＱＲタッチ有効
				local qr_status = QR.GetQRTouchStatus()
				if((qr_status == GameConnectStatus.kSuccess) or (qr_status == GameConnectStatus.kError)) then
				else
					QR.StartQRTouch()
				end

				this.nowtime_ = 0
				this.state_:SetState("Main")
			end
		end
		this.state_.func_["Main"] = function()
			-- 曲再生ステートの更新
			this:UpdateSound()

			-- 時間管理
			this.nowtime_ = this.nowtime_ + 1

			if(this.nowtime_ > this.one_song_totaltime_) then
			-- 曲の切り替え
				if(this.now_song_id_ == MusicIntroSongNum) then
					this.state_:SetState("EndWait")
				else
					-- 待ち状態になっていたら
					if(this.song_play_state_ == "Wait") then
						-- 表示の切り替え
						this.now_song_id_ = this.now_song_id_ + 1
						this:DispMusicInfo()
						this.nowtime_ = 0

						-- 曲の再生
						this:PlaySound()
					end
				end
			elseif(this.nowtime_ > this.song_play_time_) then
				-- 曲をフェードアウトする
				this:FadeOutSound()
			end
		end

		this.state_.func_["EndWait"] = function()
			-- シーン終了
			Common.LuaFinish()
			this.state_:SetState("End")
		end

		this.state_.func_["End"] = function()
		end
	end,

	-- 毎フレーム処理関数
	Update = function(this)
		-- ステートマシン実行
		this.state_:Update()
		this.banner_:Update()
	end,

	DispMusicInfo = function(this)
		this.song_info_:DispOn(this.music_info_[this.now_song_id_])

		for idx = 1,4 do
			if(this.music_info_sub_enable_[this.now_song_id_][idx] == true) then
				this.other_song_info_[idx]:DispOn(this.music_info_sub_[this.now_song_id_][idx])
			else
				this.other_song_info_[idx]:DispOff()
			end
		end
	end,
	FadeOutMusicInfo = function(this)
		this.song_info_:FadeOut()

		for idx = 1,4 do
			if(this.music_info_sub_enable_[this.now_song_id_][idx] == true) then
				this.other_song_info_[idx]:FadeOut()
			end
		end
	end,

	-- 曲の再生
	PlaySound = function(this)
		-- これから再生する曲をload
		TSound:LoadBank(this.music_info_[this.now_song_id_].song_bankname)
		this.song_play_state_ = "LoadWait"
		-- this.load_counter_ = 0 ここじゃダメ
	end,
	-- 曲のフェードアウト
	FadeOutSound = function(this)
		-- 再生中ならフェードアウト
		if(this.song_play_state_ == "Play") then
			this.load_counter_ = 0
			TSound:StopBGM(500)	-- 0.5secでフェードアウト
			this.song_play_state_ = "FadeOut"
			this:FadeOutMusicInfo()
		end
	end,

	-- 曲の更新
	UpdateSound = function(this)
		-- 曲の更新に時間がかかったら
		this.load_counter_ = this.load_counter_ + 1
		if(this.song_play_state_ == "UnloadWait") then
			-- アセットのアンロードが終わったら
			if(Common.CheckNUAssetUnload() == false) then
				this.song_play_state_ = "Wait"
			end
		elseif(this.song_play_state_ == "FadeOut") then
			-- 曲が停止したらUnLoad
			if(TSound:IsPlayingBGM() == false) then
				TSound:UnloadBank(this.music_info_[this.now_song_id_].song_bankname)
				this.song_play_state_ = "UnloadWait"
			end
		elseif(this.song_play_state_ == "LoadWait") then
			if(this.load_counter_ > (Common.FPS * 15.0)) then
				-- プログラムの強制停止→筐体再起動
				-- Common.Reboot()
			end

			-- 曲のロードが終わったらそのまま再生開始
			if(TSound:LoadedBankAll() == true) then
				-- 曲の再生
				TSound:PlayBGMSongSelect(this.music_info_[this.now_song_id_].song_bankname,0)
				this.song_play_state_ = "Play"
			end
		end
	end
}



