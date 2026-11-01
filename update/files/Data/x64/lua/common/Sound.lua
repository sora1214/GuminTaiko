-- サウンド処理
TSound = {
	player_num_ = 1,

	SetPlayerNum = function(this,Number)
		this.player_num_ = Number
	end,

	-- 再生
	-- 再生（スロット指定無し、単発で制御が不要な音）
	Play = function(this,bankName,toneName)
		Sound.PlaySound(bankName,toneName,-1)
	end,
	-- 再生（スロット指定無し、単発で制御が不要な音）
	-- プレイヤー番号を指定してtoneNameの後ろに_?Pを付けて再生、プレイ人数に応じてパンを振る
	PlayMulti = function(this,playerNo,bankName,toneName)
		local workStr = str(toneName..(playerNo + 1).."P")
		Sound.PlaySoundMulti(this.player_num_,playerNo,bankName,workStr,-1)
	end,
	-- 再生（スロット指定無し、単発で制御が不要な音）
	-- プレイヤー番号を指定してtoneNameの後ろに_?Pを付けて再生(パンは振らない)
	PlayMultiCenter = function(this,playerNo,bankName,toneName)
		local workStr = str(toneName..(playerNo + 1).."P")
		Sound.PlaySound(bankName,workStr,-1)
	end,
	-- スロット指定で再生（ループ音など制御が必要な音）
	PlaySlot = function(this,bankName,toneName,slotNo)
		Sound.PlaySound(bankName,toneName,slotNo)
	end,
	-- スロット指定で再生（ループ音など制御が必要な音）
	-- プレイヤー番号を指定してtoneNameの後ろに_?Pを付けて再生、プレイ人数に応じてパンを振る
	PlaySlotMulti = function(this,playerNo,bankName,toneName,slotNo)
		local workStr = str(toneName..(playerNo + 1).."P")
		Sound.PlaySoundMulti(this.player_num_,playerNo,bankName,workStr,slotNo)
	end,

	-- 停止
	-- スロット指定で停止（ループ音など）
	StopSlot = function(this,slotNo)
		Sound.StopSoundSlot(slotNo)
	end,
	-- バンク指定で停止（バンク内の全てのトーンを停止）
	StopBank = function(this,bankName)
		Sound.StopSoundBank(bankName)
	end,

	-- 再生チェック
	IsPlayingSlot = function(this,slotNo)
		return Sound.IsPlayingSoundSlot(slotNo)
	end,
	IsPlayingBank = function(this,bankName)
		return Sound.IsPlayingSoundBank(bankName)
	end,

	-- 音量設定
	SetVolumeSlot = function(this,slotNo,volume,nTime)
		Sound.SetVolumeSoundSlot(slotNo,volume,nTime)
	end,

	-- ＢＧＭの再生
	PlayBGM = function(this,bankName)
		Sound.PlayBGM(bankName)
	end,
	PlayBGMSongSelect = function(this,bankName)
		Sound.PlayBGMSongSelect(bankName)
	end,
	StopBGM = function(this,fadeTime)
		Sound.StopBGM(fadeTime)
	end,
	IsPlayingBGM = function(this)
		return Sound.IsPlayingBGM()
	end,

	-- bank操作
	LoadBank = function(this,bankName)
		Sound.LoadBank(bankName)
	end,
	UnloadBank = function(this,bankname)
		Sound.UnloadBank(bankname)
	end,
	LoadedBankAll = function(this)
		return Sound.LoadedBankAll()
	end,

	-- よく使うシリーズ
	-- 決定音
	PlayDecide = function(this)
		Sound.PlaySound("se_common","don_1P",-1)
	end,
	-- 選択音
	PlaySelect = function(this)
		Sound.PlaySound("se_common","katsu_1P",-1)
	end



}
