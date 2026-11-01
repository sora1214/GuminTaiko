-- DaniResult.lua
-- 段位リザルト画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/enso_dani/result/dani_result"

-- 使うクラスを読み込む
require("common.State")
require("dani_result.DaniResultMain")

-- 定数
kDanShokyuu_	= 1
kDan5kyuu_		= 1
kDan4kyuu_		= 2
kDan3kyuu_		= 3
kDan2kyuu_		= 4
kDan1kyuu_		= 5
kDan1dan_		= 6
kDan2dan_		= 7
kDan3dan_		= 8
kDan4dan_		= 9
kDan5dan_		= 10
kDan6dan_		= 11
kDan7dan_		= 12
kDan8dan_		= 13
kDan9dan_		= 14
kDan10dan_		= 15
kDan11dan_		= 16
kDan12dan_		= 17
kDan13dan_		= 18
kDan14dan_		= 19

-- グローバル変数（Lua内で使用）
g_maxReachNum_ = 0		-- クリアできた曲数
g_maxOdaiNum_ = 0		-- お題の数(魂ゲージ除く)

-- グローバル変数（C++から値を設定）
-- プレイヤーの情報
-- g_HiScore_		: プレイヤーの段位ハイスコアリスト
-- g_joinSide_		: エントリーしている筐体（1が左 / 2が右）
-- g_daniRank_[24]	: 0: 未プレイ, 1>=: プレイ済
-- g_playerDani_	-- : プレイヤーの段位
-- g_dispDani_		: ネームプレートに段位を表示するか否か

-- プレイヤーのスコア
-- g_resultType_			: 0:クリア失敗, 1:クリア成功, 2:フルコンボ, 3:ドンダフル
-- g_tamashiiGauge_			: 魂ゲージ:0~50
-- g_tamashiiGaugeValue_	: 魂ゲージの実数値:0~100
-- g_gaugeBorder			: 魂ゲージの成功値:0~50
-- g_gaugeBorderValue_		: 魂ゲージの成功値の実数値:0~100
-- g_gaugeGoodBorder_		: 魂ゲージの大成功値:0~100

-- 曲自体の情報

-- g_songTitle_				: 曲名
-- g_totalScore_			: スコア
-- g_goodNum_				: 良
-- g_okNum_					: 可
-- g_badNum_				: 不可
-- g_maxComboNum_			: 最大コンボ数
-- g_dramrollNum_			: 連打数
-- g_difficulty_			: 難易度				: 0: easy, 1: normal, 2: hard, 3: oni, 4: ura,
-- g_diffRank_				: 難易度ランク			: 1~11
-- g_unreach_				: 未到達フラグ
-- g_isHidden_				: 曲名を？？？にするか否か[3]

-- お題関連
-- g_odaiDani_				: 階級
-- g_odaiResult_			: 合否結果
-- g_odaiType_				: お題の種類
-- g_odaiGaugeType_			: お題のゲージの種類
-- g_odaiClearType_			: お題のクリア条件		: 0: None, 1: 魂(ここでは不使用), 2: 良, 3: 可, 4:不可, 5: コンボ数, 6: 連打数, 7: スコア, 8: たたけた数
-- g_odaiBorder_			: お題達成の値
-- g_odaiGoodBorder_		: お題大成功の値
-- g_odaiNum_				: お題に対する成績

-- 演奏オプション
-- g_optionSpeed_			: オプション：スピード
-- g_optionDron_			: オプション：ドロン
-- g_optionReverse_			: オプション：あべこべ
-- g_optionRandomlv_		: オプション：ランダム
-- g_optionNoteDrawAdjust_	: オプション：音符表示位置
-- g_optionVoiceSkip_		: オプション：ボイス
-- g_optionEnsoSkip_		: オプション：演奏スキップ
-- g_optionNeiro_			: オプション：音色

-- ご褒美関連(不要)
--"g_getRewardNum_"					: 獲得したごほうびの数
--"g_rewardType_"					: ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
--"g_rewardUniqueId_"				: ごほうびUID
--"g_rewardMessage_"				: ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
--"g_rewardValue_"					: 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
--"g_rewardNameKey_"				: ごほうびの名称を指すワードリストのキー
--"g_rewardTokenId_"				: ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
--"g_rewardTokenNeedPoint_"			: 必要なトークン量。トークンIDが有効な時のみ参照してください

--"g_noticeRewardNum_"				: 予告ごほうびの個数
--"g_rewardNoticeType_"				: 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
--"g_rewardNoticeUniqueId_"			: 予告ごほうびUID
--"g_rewardNoticeValue_"			: 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
--"g_rewardNoticeNameKey_"			: 予告ごほうびの名称を指すワードリストのキー
--"g_rewardNoticeTokenId_"			: ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
--"g_rewardNoticeTokenNeedPoint_"	: 必要なトークン量。トークンIDが有効な時のみ参照してください

-- 報酬関連
g_isFolder_		= true		-- : true:段位フォルダ追加のお知らせを出す, false:出さない
g_isShodan_		= true		-- : true:昇段演出を出す, false:出さない
g_isPresent_	= true		-- : true:ご褒美獲得演出を出す, false:出さない
g_isCongrats_	= true		-- : true:最高段位到達演出を出す, false:出さない
g_isBestScore_	= true		-- : rtue:ベスト記録更新演出を出す, false:出さない
g_isSkip_		= false		-- : rtue:スキップを使用, false:未使用

--dani_result_congrats

-- デバッグ用
g_DebugNum = 0				-- : デバッグ用の値

-- 初期化処理
function Init()
-- TODO:後で消す
	
	Debug.PrintString("g_HiScore_[1] :"..g_HiScore_[1])
	Debug.PrintString("g_HiScore_[2] :"..g_HiScore_[2])
	Debug.PrintString("g_HiScore_[3] :"..g_HiScore_[3])

	-- 到達未到達設定
	SetUnReach()

	Debug.PrintString("[DaniResult] Init")
	DaniResultMain:Init()

	-- ダミーの設定
	--SetDebugStatus()
	if(g_DebugNum == 1 or g_DebugNum >= 4)then
		Debug.PrintString("g_DebugNum = 1")
		SetDummyData_1()
		--g_joinSide_ = 2
	elseif(g_DebugNum == 2)then
		Debug.PrintString("g_DebugNum = 2")
		SetDummyData_2()
	elseif(g_DebugNum == 3)then
		Debug.PrintString("g_DebugNum = 3")
		SetDummyData_3()
	end

	-- お題の数を設定
	SetMaxOdaiNum()

	-- 到達した曲の数を設定
	SetMaxReachNum()

	-- 曲名の???設定
	SetSongHidden()

	-- お題に対する成績の設定
	SetOdaiNum()

	-- お題の合否結果を設定
	SetOdaiResult()

	-- 追加演出を行うか否か設定
	CheckReward()
	--g_dispDani_ = true	-- ネームプレートの段位を表示する。

	--g_isFolder_		= false		-- : true:段位フォルダ追加のお知らせを出す, false:出さない
	--g_isShodan_		= true		-- : true:昇段演出を出す, false:出さない
	--g_isPresent_	= false		-- : true:ご褒美獲得演出を出す, false:出さない


	if(g_DebugNum == 4)then
		Debug.PrintString("g_DebugNum = 4")
		SetDummyData_4(1)
	elseif(g_DebugNum == 5)then
		Debug.PrintString("g_DebugNum = 5")
		SetDummyData_5(2)
	elseif(g_DebugNum == 6)then
		Debug.PrintString("g_DebugNum = 6")
		SetDummyData_4(3)
	elseif(g_DebugNum == 7)then
		Debug.PrintString("g_DebugNum = 7")
		SetDummyData_4(4)
	elseif(g_DebugNum == 8)then
		Debug.PrintString("g_DebugNum = 8")
		SetDummyData_5(5)
	elseif(g_DebugNum == 9)then
		Debug.PrintString("g_DebugNum = 9")
		SetDummyData_4(6)
	end

end

-- 毎フレームの処理
function Proc()
	DaniResultMain:Update()
end

-- ドン入力
function InputDon()
	if(g_joinSide_ == 1)then 
		if (Input.GetTrigger(Input.PLAYER1_OK) or Input.GetTrigger(Input.PLAYER1_CANCEL))then
			Debug.PrintString("Don 1P")
			return true
		end
	else
		if (Input.GetTrigger(Input.PLAYER2_OK) or Input.GetTrigger(Input.PLAYER2_CANCEL))then
			Debug.PrintString("Don 2P")
			return true
		end
	end

	return false
end

function SetStatus()
	-- 値の設定
end

-- 到達した曲の数を設定
function SetUnReach()
	for idx = 1, 3 do
		if(g_unreach_[idx] == false)then
			-- 到達
			g_unreach_[idx] = false
		else
			if(g_goodNum_[idx] == 0 and g_okNum_[idx] == 0 and g_badNum_[idx] == 0)then
				-- 未到達
				g_unreach_[idx] = true
			else
				-- 到達(スキップを使用)
				g_unreach_[idx] = false
				g_isBestScore_ = false
				g_isFolder_ = false
				g_isSkip_ = true
			end
		end
	end
end

-- 到達した曲の数を設定
function SetMaxReachNum()
	for idx = 1, 3 do
		if(g_unreach_[idx] == false)then
			g_maxReachNum_ = idx
		else
			if(g_goodNum_[idx] == 0 and g_okNum_[idx] == 0 and g_badNum_[idx] == 0)then
				-- 未到達
			else
				-- 到達
				g_maxReachNum_ = idx
			end
		end
	end
	Debug.PrintString("g_maxReachNum_ = "..g_maxReachNum_)
end

-- 到達した曲の数を設定
function SetSongHidden()
	Debug.PrintString("SetSongHidden")
	Debug.PrintString("SetSongHidden:"..g_odaiDani_)
	local daniInfo = Cabinet.DaniInfo(g_odaiDani_)
	for idx = 1, 3 do
		g_isHidden_[idx] = daniInfo.is_hiddens[idx]
		if(g_isHidden_[idx] == true)then
			Debug.PrintString("hidden : true")
		else
			Debug.PrintString("hidden : false")
		end
	end
	Debug.PrintString("SetSongHidden finish")
end

-- お題の数を設定
function SetMaxOdaiNum()
	for idx = 1, 3 do
		if(g_odaiClearType_[idx] ~= 0)then
			g_maxOdaiNum_ = idx
		end
	end
	Debug.PrintString("g_maxOdaiNum_ = "..g_maxOdaiNum_)
end

-- お題に対する成績の設定
function SetOdaiNum()
	for i = 1, 3 do
		if(g_odaiType_[i] == 3)then
			-- 1曲毎
			for j = 1, 3 do
				-- 曲数 = j

				-- お題のクリア条件
				-- 0: None, 1: 魂(ここでは不使用), 2: 良, 3: 可, 4:不可, 5: コンボ数, 6: 連打数, 7: スコア, 8: たたけた数
				if(g_odaiClearType_[i] == 2)then
					-- 良
					g_odaiNum_[i][j] = g_goodNum_[j]

				elseif(g_odaiClearType_[i] == 3)then
					-- 可
					g_odaiNum_[i][j] = g_okNum_[j]

				elseif(g_odaiClearType_[i] == 4)then
					-- 不可
					g_odaiNum_[i][j] = g_badNum_[j]

				elseif(g_odaiClearType_[i] == 5)then
					-- コンボ数
					--g_odaiNum_[i][j] = g_maxComboNum_[j]
					g_odaiNum_[i][j] = g_maxComboNum_

				elseif(g_odaiClearType_[i] == 6)then
					-- 連打数
					g_odaiNum_[i][j] = g_dramrollNum_[j]

				elseif(g_odaiClearType_[i] == 7)then
					-- スコア
					g_odaiNum_[i][j] = g_totalScore_[j]

				elseif(g_odaiClearType_[i] == 8)then
					-- 叩けた数
					g_odaiNum_[i][j] = g_goodNum_[j] + g_okNum_[j] + g_dramrollNum_[j]

				end
			end
		else
			-- 3曲合計お題

			-- お題のクリア条件
			-- 0: None, 1: 魂(ここでは不使用), 2: 良, 3: 可, 4:不可, 5: コンボ数, 6: 連打数, 7: スコア, 8: たたけた数
			if(g_odaiClearType_[i] == 2)then
				-- 良
				g_odaiNum_[i][1] = g_goodNum_[1] + g_goodNum_[2] + g_goodNum_[3]

			elseif(g_odaiClearType_[i] == 3)then
				-- 可
				g_odaiNum_[i][1] = g_okNum_[1] + g_okNum_[2] + g_okNum_[3]

			elseif(g_odaiClearType_[i] == 4)then
				-- 不可
				g_odaiNum_[i][1] = g_badNum_[1] + g_badNum_[2] + g_badNum_[3]

			elseif(g_odaiClearType_[i] == 5)then
				-- コンボ数
				--g_odaiNum_[i][1] = g_maxComboNum_[1] + g_maxComboNum_[2] + g_maxComboNum_[3]
				g_odaiNum_[i][1] = g_maxComboNum_

			elseif(g_odaiClearType_[i] == 6)then
				-- 連打数
				g_odaiNum_[i][1] = g_dramrollNum_[1] + g_dramrollNum_[2] + g_dramrollNum_[3]

			elseif(g_odaiClearType_[i] == 7)then
				-- スコア
				g_odaiNum_[i][1] = g_totalScore_[1] + g_totalScore_[2] + g_totalScore_[3]

			elseif(g_odaiClearType_[i] == 8)then
				-- 叩けた数
				g_odaiNum_[i][1] = g_goodNum_[1] + g_goodNum_[2] + g_goodNum_[3] + g_okNum_[1] + g_okNum_[2] + g_okNum_[3] + g_dramrollNum_[1] + g_dramrollNum_[2] + g_dramrollNum_[3]

			end
		end
	end
end

-- お題の合否結果を設定
function SetOdaiResult()
	Debug.PrintString("SetOdaiResult")
	local check		= CheckResult()
	local okNum		= g_okNum_[1] + g_okNum_[2]	+ g_okNum_[3]		-- 可
	local badNum	= g_badNum_[1] + g_badNum_[2] + g_badNum_[3]	-- 不可

	if(check == 2)then
		-- 大成功
		if(badNum == 0)then
			if(okNum == 0)then
				-- ドンダフルコンボ
				g_odaiResult_ = 6
			else
				-- フルコンボ
				g_odaiResult_ = 5
			end
		else
			g_odaiResult_ = 4
		end
	elseif(check == 1)then
		-- 合格
		if(badNum == 0)then
			if(okNum == 0)then
				-- ドンダフルコンボ
				g_odaiResult_ = 3
			else
				-- フルコンボ
				g_odaiResult_ = 2
			end
		else
			g_odaiResult_ = 1
		end
	else
		-- 不合格
		g_odaiResult_ = 0
	end

	if(g_isSkip_ == true)then
		-- スキップ使用時は必ず不合格にする。
		g_odaiResult_ = 0
	end

	Debug.PrintString("g_odaiResult_ : "..g_odaiResult_)
end

-- 合否チェック
function CheckResult()
	Debug.PrintString("CheckResult")
	local ok	= 0
	local good	= 0
	local check = {}

	-- 詳細リザルト
	for idx = 1, g_maxOdaiNum_ do
		check[idx] = CheckResultDetail(idx)
	end
	-- 魂ゲージ
	check[g_maxOdaiNum_+1] = CheckResultGauge()

	for idx = 1, g_maxOdaiNum_+1 do
		Debug.PrintString("check : "..check[idx])
	end

	for idx = 1, g_maxOdaiNum_+1 do
		if(check[idx] == 1)then
			ok = ok+1
		elseif(check[idx] == 2)then
			good = good+1
		end
	end

	-- 判定
	if(good == g_maxOdaiNum_+1)then
		return 2
	elseif((ok + good) == g_maxOdaiNum_+1)then
		return 1
	else
		return 0
	end
end

-- 魂ゲージの判定
function CheckResultGauge()
	-- 合否チェック(魂ゲージの合否)
	-- 0:不合格, 1:合格, 2:大成功合格
	Debug.PrintString("CheckResult")

	if(g_tamashiiGaugeValue_ >= g_gaugeBorderValue_)then
		
		if(g_tamashiiGaugeValue_ >= g_gaugeGoodBorder_)then
			return 2
		end

		return 1
	end

	return 0
end

-- 追加演出を行うか判定
function CheckReward()
	-- 段位追加お知らせウィンドウ
	Debug.PrintString("CheckReward")
	local flagFolder = true
	for idx = 1, 24 do
		Debug.PrintString("idx:"..idx)
		if(g_daniRank_[idx] > 0)then
			flagFolder = false
		end
	end

	-- スキップ使用時、フォルダ表示は行わないように制御
	if(g_isFolder_ == true)then
		g_isFolder_ = flagFolder
	end
	if(g_isFolder_ == true)then
		Debug.PrintString("段位追加お知らせウィンドウ:true")
	else
		Debug.PrintString("段位追加お知らせウィンドウ:false")
	end

	-- ご褒美ウィンドウ
	--local flagPresent = false
	--for idx = 1, 3 do
	--	if(g_getRewardNum_[idx] > 0)then
	--		flagPresent = true
	--	end
	--end
	--g_isPresent_ = flagPresent
	g_isPresent_ = false
	
	-- 昇格ウィンドウ
	g_isCongrats_ = false
	if(g_odaiResult_ > 0)then
		if(g_daniRank_[g_odaiDani_] < (g_odaiResult_+1))then
			g_isShodan_ = true
			Debug.PrintString("昇段ウィンドウ:true")
			Debug.PrintString("g_daniRank_:"..g_daniRank_[g_odaiDani_])
			Debug.PrintString("g_odaiResult_:"..g_odaiResult_+1)

			-- 今回の挑戦段位が最高段位の場合
			if(g_odaiDani_ == kDan14dan_)then g_isCongrats_ = true end

		else
			g_isShodan_ = false
		end
	else
		g_isShodan_ = false
		Debug.PrintString("昇段ウィンドウ:false")
		Debug.PrintString("g_daniRank_:"..g_daniRank_[g_odaiDani_])
		Debug.PrintString("g_odaiResult_:"..g_odaiResult_+1)
	end

	-- ベストスコア
	if(g_daniRank_[g_odaiDani_] > (g_odaiResult_+1))then
		g_isBestScore_ = false
	end

	if(g_daniRank_[g_odaiDani_] == 0)then
		g_isBestScore_ = false
	end
end

-- 各お題の判定
-- 不合格, 合格, 大成功の判定
-- 0:不合格, 1:合格, 2:大成功合格
function CheckResultDetail(odaiIdx)
	Debug.PrintString("CheckResultDetail")
	Debug.PrintString("odaiIdx = "..odaiIdx)

	if(g_maxReachNum_ ~= 3)then
		-- 3曲分到達できなかった場合、未到達
		return 0
	end

	local bad		= 0		-- 不合格
	local ok		= 0		-- 成功
	local good		= 0		-- 大成功

	-- 不合格, 成功, 大成功の判定
	if(g_odaiType_[odaiIdx] == 0)then
		-- ゲージ1つ分の判定
		if(g_odaiGaugeType_[odaiIdx] == 0)then
			-- 0から増えるゲージ
			if(g_odaiNum_[odaiIdx][1] >= g_odaiBorder_[odaiIdx][1])then
				-- 成功ラインを超えている
				if(g_odaiNum_[odaiIdx][1] >= g_odaiGoodBorder_[odaiIdx][1])then
					-- 大成功ラインを超えている
					return 2
				end
				return 1
			end
			return 0
		else
			-- 100から減るゲージ
			if(g_odaiNum_[odaiIdx][1] < g_odaiBorder_[odaiIdx][1])then
				-- 成功ラインを超えている
				if(g_odaiNum_[odaiIdx][1] < g_odaiGoodBorder_[odaiIdx][1])then
					-- 大成功ラインを超えている
					return 2
				end
				return 1
			end
			return 0
		end
	else
		-- ゲージ3つ分の判定
		if(g_odaiGaugeType_[odaiIdx] == 0)then
			-- 0から増えるゲージ
			for idx = 1, 3 do
				if(g_odaiNum_[odaiIdx][idx] >= g_odaiBorder_[odaiIdx][idx])then
					-- 成功ラインを超えている
					if(g_odaiNum_[odaiIdx][idx] >= g_odaiGoodBorder_[odaiIdx][idx])then
						-- 大成功ラインを超えている
						good = good+1
					else
						ok = ok+1
					end
				end
			end

			-- 判定
			if(good == 3)then
				return 2
			end

			if((ok + good) == 3)then
				return 1
			end
			
			return 0
		else
			-- 100から減るゲージ
			for idx = 1, 3 do
				if(g_odaiNum_[odaiIdx][idx] < g_odaiBorder_[odaiIdx][idx])then
					-- 成功ラインを超えている
					if(g_odaiNum_[odaiIdx][idx] < g_odaiGoodBorder_[odaiIdx][idx])then
						-- 大成功ラインを超えている
						good = good+1
					else
						ok = ok+1
					end
				end
			end

			-- 判定
			if(good == 3)then
				return 2
			end
			
			if((ok + good) == 3)then
				return 1
			end

			return 0
			
		end
	end
end


-- デバッグ用の設定
function SetDebugStatus()

	-- スコア
	g_tamashiiGauge_		= 50				-- 魂ゲージ(0~50)
	g_tamashiiGaugeValue_	= 100				-- 魂ゲージ実数値
	--g_gaugeBorder_		= 45				-- 魂ゲージボーダー(0~50)
	g_maxComboNum_			= 1234				-- 最大コンボ数

	for idx = 1, 3 do
		g_songTitle_[idx]	= "dhero2"			-- 曲名
--		g_songTitle_[idx]	= "song_dhero2"		-- 曲名
--		g_songTitle_[idx]	= "song_detail_dhero2"		-- 曲名ルビ
		g_totalScore_[idx]	= 1111111			-- スコア
		g_goodNum_[idx]		= 1234				-- 良
		g_okNum_[idx]		= 0					-- 可
		g_badNum_[idx]		= 0					-- 不可
		g_dramrollNum_[idx]	= 1234				-- 連打数
		g_difficulty_[idx]	= 1+idx				-- 難易度
		g_diffRank_[idx]	= 3*idx				-- 難易度ランク
		g_unreach_[idx]		= false				-- 未到達フラグ
	end

	-- test : 〇番目だけ未到達に設定
	g_unreach_[3] = true

	-- お題関連
	g_odaiDani_		= 0		-- 階級
	g_odaiResult_	= 1		-- 合否結果

	g_odaiType_[1]	= 0		-- お題の種類(0: ALL, 1:1st, 2:2nd, 3:3rd)
	g_odaiType_[2]	= 3
	g_odaiType_[3]	= 3

	g_odaiGaugeType_[1]	= 0		-- ゲージの種類(0:0から増えていくゲージ, 1:100から減っていくゲージ)
	g_odaiGaugeType_[2] = 0
	g_odaiGaugeType_[3]	= 1

	g_odaiClearType_[1] = 5		-- お題のクリア条件
	g_odaiClearType_[2] = 6
	g_odaiClearType_[3] = 2

	-- お題の種類ごとにお題内容を設定
	for idx = 1, 3 do
		if(g_odaiType_[idx] == 0)then
			-- お題の種類がALL
			if(g_odaiGaugeType_[idx] == 0)then
				-- 0から増えていくゲージ
--				g_odaiClearType_[idx][1]	= 0		-- お題のクリア条件
				g_odaiBorder_[idx][1]		= 50000	-- お題達成の値(以上)
				g_odaiGoodBorder_[idx][1]	= 52000	-- お題大成功の値(以上)
				g_odaiNum_[idx][1]			= 52999	-- お題に対する成績
			else
				-- 100から減っていくゲージ
--				g_odaiClearType_[idx][1]	= 0		-- お題のクリア条件
				g_odaiBorder_[idx][1]		= 10	-- お題達成の値(未満)
				g_odaiGoodBorder_[idx][1]	= 0		-- お題大成功の値(未満)
				g_odaiNum_[idx][1]			= 0		-- お題に対する成績
			end
		else
			-- お題の種類がALL以外
			if(g_odaiGaugeType_[idx] == 0)then
				-- 0から増えていくゲージ
				for i = 1, 3 do
--					g_odaiClearType_[idx][i]	= 0					-- お題のクリア条件
					g_odaiBorder_[idx][i]		= 150*i				-- お題達成の値(以上)
					g_odaiGoodBorder_[idx][i]	= 170*i				-- お題大成功の値(以上)
					g_odaiNum_[idx][i]			= 160*i				-- お題に対する成績
				end
			else
				-- 100から減っていくゲージ
				for i = 1, 3 do
--					g_odaiClearType_[idx][i]	= 0					-- お題のクリア条件
					g_odaiBorder_[idx][i]		= 5*i				-- お題達成の値(未満)
					g_odaiGoodBorder_[idx][i]	= 0					-- お題大成功の値(未満)
					g_odaiNum_[idx][i]			= 0					-- お題に対する成績
				end
			end
		end
	end

	-- オプション
	g_optionSpeed_ = 1				-- オプション：スピード
	g_optionDron_ = false			-- オプション：ドロン
	g_optionReverse_ = false		-- オプション：あべこべ
	g_optionRandomlv_ = 1			-- オプション：ランダム
	g_optionNoteDrawAdjust_ = 1		-- オプション：音符表示位置
end

-- デバッグ用に仮パラメータの設定
-- スコア		: すべて最大値
-- 曲			: 1 : 難易度かんたん☆2, 2 : 難易度ふつう☆4, 3 : 難易度むずかしい☆6
-- お題			
-- 1曲目 : スコア、3曲合計、増えるゲージ
-- 2曲目 : コンボ数、1曲毎、増えるゲージ
-- 3曲目 : 不可、1曲毎、減るゲージ
-- オプション	: すべて設定する

function SetDummyData_1()
	Debug.PrintString("[DaniResult] SetDummyData_1")

	---------------------------------------
	-- 曲
	for idx = 1, 3 do
		g_songTitle_[idx]	= "dhero2"			-- 曲名
--		g_songTitle_[idx]	= "song_dhero2"		-- 曲名
		g_diffRank_[idx]	= idx				-- 難易度
		g_difficulty_[idx]	= idx-1				-- 難易度ランク
	end

	---------------------------------------
	-- お題関連

	g_odaiDani_ = kDan14dan_	-- 階級
	g_odaiResult_ = 6	-- 合否結果

	-- お題の種類
	-- 0: ALL, 1:1st, 2:2nd, 3:3rd
	g_odaiType_[1]	= 0
	g_odaiType_[2]	= 3
	g_odaiType_[3]	= 0

	-- お題のクリア条件
	-- 0: None, 1: 魂(ここでは不使用), 2: 良, 3: 可, 4:不可, 5: コンボ数, 6: 連打数, 7: スコア, 8: たたけた数
	g_odaiClearType_[1] = 7		-- スコア
	g_odaiClearType_[2] = 5		-- コンボ数
	g_odaiClearType_[3] = 4		-- 不可

	-- ゲージの種類
	-- 0:0から増えていくゲージ, 1:100から減っていくゲージ
	g_odaiGaugeType_[1]	= 0		
	g_odaiGaugeType_[2] = 0
	g_odaiGaugeType_[3]	= 1

	-- お題達成の値
	-- スコア
	g_odaiBorder_[1][1] = 1111
	--g_odaiBorder_[1][2] = 1111
	--g_odaiBorder_[1][3] = 1111
	-- コンボ数
	g_odaiBorder_[2][1] = 1111
	g_odaiBorder_[2][2] = 1111
	g_odaiBorder_[2][3] = 1111
	-- 不可
	g_odaiBorder_[3][1] = 123
	g_odaiBorder_[3][2] = 1111
	g_odaiBorder_[3][3] = 115

	-- お題大成功の値
	-- スコア
	g_odaiGoodBorder_[1][1] = 1111
	--g_odaiGoodBorder_[1][2] = 1111
	--g_odaiGoodBorder_[1][3] = 1111
	-- コンボ数
	g_odaiGoodBorder_[2][1] = 1111
	g_odaiGoodBorder_[2][2] = 1111
	g_odaiGoodBorder_[2][3] = 1111
	-- 不可
	g_odaiGoodBorder_[3][1] = 1111
	g_odaiGoodBorder_[3][2] = 1111
	g_odaiGoodBorder_[3][3] = 1111

	--------------------------------------
	-- 演奏結果

	-- 魂ゲージ
	g_tamashiiGauge_ = 50
	g_tamashiiGaugeValue_	= 100				-- 魂ゲージ実数値
	-- 魂ゲージの成功ライン
	g_gaugeBorder_ = 47
	g_gaugeBorderValue_ = 95

	-- 各曲スコア
	for idx = 1, 3 do
		g_totalScore_[idx]	= 1999 -- 各曲スコア
		g_goodNum_[idx]		= 1999 -- 良
		g_okNum_[idx]		= 0    -- 可
		g_badNum_[idx]		= 0	   -- 不可
--		g_maxComboNum_[idx]	= 1999 -- 最大コンボ数
		g_dramrollNum_[idx]	= 1999 -- 連打数

		g_unreach_[idx]		= false	-- 未到達
	end
	g_maxComboNum_			= 1999  -- 最大コンボ数

	-- お題に対する成績
	-- スコア
	g_odaiNum_[1][1] = g_totalScore_[1] + g_totalScore_[2] + g_totalScore_[3]
--	g_odaiNum_[1][2] = 
--	g_odaiNum_[1][3] = 

	-- コンボ数
	g_odaiNum_[2][1] = g_maxComboNum_
	g_odaiNum_[2][2] = g_maxComboNum_
	g_odaiNum_[2][3] = g_maxComboNum_

	-- 不可
	g_odaiNum_[3][1] = g_badNum_[1]
	g_odaiNum_[3][2] = g_badNum_[2]
	g_odaiNum_[3][3] = g_badNum_[3]

	--------------------------------------
	-- 演奏オプション(表示に必要な部分のみ設定)
	g_optionSpeed_ = 0				-- オプション：スピード
	g_optionDron_ = false			-- オプション：ドロン
	g_optionReverse_ = false		-- オプション：あべこべ
	g_optionRandomlv_ = 0			-- オプション：ランダム
	g_optionNoteDrawAdjust_ = 0		-- オプション：音符表示位置

	--------------------------------------
	-- 報酬関連
	g_isFolder_		= true		-- : true:段位フォルダ追加のお知らせを出す, false:出さない
	g_isShodan_		= true		-- : true:昇段演出を出す, false:出さない
	g_isPresent_	= false		-- : true:ご褒美獲得演出を出す, false:出さない
	g_dispDani_		= true		-- ネームプレートの段位を表示する。

end

-- デバッグ用に仮パラメータの設定
-- スコア	: すべて0、3曲目は未到達
-- 曲		: 1 : 難易度かんたん☆2, 2 : 難易度ふつう☆4, 3 : 難易度むずかしい☆6
-- お題			
-- 1曲目 : スコア、3曲合計、増えるゲージ
-- 2曲目 : コンボ数、1曲毎、増えるゲージ
-- 3曲目 : 不可、1曲毎、減るゲージ
-- オプション	: すべて設定しない
function SetDummyData_2()
Debug.PrintString("[DaniResult] SetDummyData_2")
	---------------------------------------
	-- 曲
	for idx = 1, 3 do
--		g_songTitle_[idx]	= "song_dhero2"		-- 曲名
		g_songTitle_[idx]	= "dhero2"			-- 曲名
		g_diffRank_[idx]	= idx*2				-- 難易度
		g_difficulty_[idx]	= idx+1				-- 難易度ランク
	end

	---------------------------------------
	-- お題関連

	g_odaiDani_ = 1		-- 階級
	g_odaiResult_ = 0	-- 合否結果

	-- お題の種類
	-- 0: ALL, 1:1st, 2:2nd, 3:3rd
	g_odaiType_[1]	= 0
	g_odaiType_[2]	= 3
	g_odaiType_[3]	= 3

	-- お題のクリア条件
	-- 0: 良, 1: 可, 2:不可, 3: コンボ数, 4: 連打数, 5: スコア, 6: たたけた数
	g_odaiClearType_[1] = 6		-- たたけた数
	g_odaiClearType_[2] = 4		-- 連打数
	g_odaiClearType_[3] = 1		-- 可

	-- ゲージの種類
	-- 0:0から増えていくゲージ, 1:100から減っていくゲージ
	g_odaiGaugeType_[1]	= 0		
	g_odaiGaugeType_[2] = 0
	g_odaiGaugeType_[3]	= 1

	-- お題達成の値
	-- スコア
	g_odaiBorder_[1][1] = 100
	--g_odaiBorder_[1][2] = 0
	--g_odaiBorder_[1][3] = 0
	-- コンボ数
	g_odaiBorder_[2][1] = 100
	g_odaiBorder_[2][2] = 100
	g_odaiBorder_[2][3] = 100
	-- 不可
	g_odaiBorder_[3][1] = 5
	g_odaiBorder_[3][2] = 10
	g_odaiBorder_[3][3] = 15

	-- お題大成功の値
	-- スコア
	g_odaiGoodBorder_[1][1] = 120
	--g_odaiGoodBorder_[1][2] = 0
	--g_odaiGoodBorder_[1][3] = 0
	-- コンボ数
	g_odaiGoodBorder_[2][1] = 120
	g_odaiGoodBorder_[2][2] = 120
	g_odaiGoodBorder_[2][3] = 120
	-- 不可
	g_odaiGoodBorder_[3][1] = 10
	g_odaiGoodBorder_[3][2] = 15
	g_odaiGoodBorder_[3][3] = 20

	--------------------------------------
	-- 演奏結果

	-- 魂ゲージ
	g_tamashiiGauge_ = 0
	g_tamashiiGaugeValue_	= 0				-- 魂ゲージ実数値
	-- 魂ゲージの成功ライン
	g_gaugeBorder_ = 25
	g_gaugeBorderValue_ = 50

	-- 各曲スコア
	for idx = 1, 3 do
		g_totalScore_[idx]	= 0 -- 各曲スコア
		g_goodNum_[idx]		= 0 -- 良
		g_okNum_[idx]		= 30 -- 可
		g_badNum_[idx]		= 30 -- 不可
		--g_maxComboNum_[idx]	= 0 -- 最大コンボ数
		g_dramrollNum_[idx]	= 0 -- 連打数

		g_unreach_[idx]		= false	-- 未到達
	end

	g_unreach_[3] = true
	g_maxComboNum_			= 1999  -- 連打数

	-- お題に対する成績
	-- たたけた数
	g_odaiNum_[1][1] = g_goodNum_[1] + g_goodNum_[2] + g_goodNum_[3] + g_okNum_[1] + g_okNum_[2] + g_okNum_[3] + g_dramrollNum_[1] + g_dramrollNum_[2] + g_dramrollNum_[3]
--	g_odaiNum_[1][2] = 
--	g_odaiNum_[1][3] = 
	-- 連打数
	g_odaiNum_[2][1] = g_dramrollNum_[1]
	g_odaiNum_[2][2] = g_dramrollNum_[2]
	g_odaiNum_[2][3] = g_dramrollNum_[3]
	-- 可
	g_odaiNum_[3][1] = g_okNum_[1]
	g_odaiNum_[3][2] = g_okNum_[2]
	g_odaiNum_[3][3] = g_okNum_[3]
	
	--------------------------------------
	-- 演奏オプション(表示に必要な部分のみ設定)
	g_optionSpeed_ = 0				-- オプション：スピード
	g_optionDron_ = false			-- オプション：ドロン
	g_optionReverse_ = false		-- オプション：あべこべ
	g_optionRandomlv_ = 0			-- オプション：ランダム
	g_optionNoteDrawAdjust_ = 0		-- オプション：音符表示位置
	
	--------------------------------------
	-- 報酬関連
	g_isFolder_		= false		-- : true:段位フォルダ追加のお知らせを出す, false:出さない
	g_isShodan_		= false		-- : true:昇段演出を出す, false:出さない
	g_isPresent_	= false		-- : true:ご褒美獲得演出を出す, false:出さない
end

-- デバッグパラメータ3
-- 曲数分のパラメータを設定
-- スコア	: すべて0、3曲目は未到達
-- 曲		: 1 : 難易度かんたん☆2, 2 : 難易度ふつう☆4, 3 : 難易度むずかしい☆6
-- お題			
-- 1曲目 : スコア、3曲合計、増えるゲージ
-- 2曲目 : コンボ数、1曲毎、増えるゲージ
-- 3曲目 : 不可、1曲毎、減るゲージ
-- オプション	: すべて設定しない
function SetDummyData_3()
	Debug.PrintString("[DaniResult] SetDummyData_3")

	-- 未到達(trueで未到達)
	g_unreach_[1] = false
	g_unreach_[2] = true
	g_unreach_[3] = true

	---------------------------------------
	-- 曲
	for idx = 1, 3 do
		g_songTitle_[idx]	= "dhero2"			-- 曲名
		g_diffRank_[idx]	= idx*2				-- 難易度
		g_difficulty_[idx]	= idx+1				-- 難易度ランク
	end

	---------------------------------------
	-- お題関連

	g_odaiDani_ = 1		-- 階級
	g_odaiResult_ = 0	-- 合否結果

	-- お題の種類
	-- 0: ALL, 1:1st, 2:2nd, 3:3rd
	g_odaiType_[1]	= 0
	g_odaiType_[2]	= 3
	g_odaiType_[3]	= 3

	-- お題のクリア条件
	-- 0: 良, 1: 可, 2:不可, 3: コンボ数, 4: 連打数, 5: スコア, 6: たたけた数
	g_odaiClearType_[1] = 6		-- たたけた数
	g_odaiClearType_[2] = 4		-- 連打数
	g_odaiClearType_[3] = 1		-- 可

	-- ゲージの種類
	-- 0:0から増えていくゲージ, 1:100から減っていくゲージ
	g_odaiGaugeType_[1]	= 0		
	g_odaiGaugeType_[2] = 0
	g_odaiGaugeType_[3]	= 1

	-- お題達成の値
	-- スコア
	g_odaiBorder_[1][1] = 100
	--g_odaiBorder_[1][2] = 0
	--g_odaiBorder_[1][3] = 0
	-- コンボ数
	g_odaiBorder_[2][1] = 100
	g_odaiBorder_[2][2] = 100
	g_odaiBorder_[2][3] = 100
	-- 不可
	g_odaiBorder_[3][1] = 5
	g_odaiBorder_[3][2] = 10
	g_odaiBorder_[3][3] = 15

	-- お題大成功の値
	-- スコア
	g_odaiGoodBorder_[1][1] = 120
	--g_odaiGoodBorder_[1][2] = 0
	--g_odaiGoodBorder_[1][3] = 0
	-- コンボ数
	g_odaiGoodBorder_[2][1] = 120
	g_odaiGoodBorder_[2][2] = 120
	g_odaiGoodBorder_[2][3] = 120
	-- 不可
	g_odaiGoodBorder_[3][1] = 10
	g_odaiGoodBorder_[3][2] = 15
	g_odaiGoodBorder_[3][3] = 20

	--------------------------------------
	-- 演奏結果

	-- 魂ゲージ
	g_tamashiiGauge_ = 0
	g_tamashiiGaugeValue_	= 0				-- 魂ゲージ実数値
	-- 魂ゲージの成功ライン
	g_gaugeBorder_ = 45
	g_gaugeBorderValue_ = 90

	-- 各曲スコア
	for idx = 1, 3 do
		g_totalScore_[idx]	= 0 -- 各曲スコア
		g_goodNum_[idx]		= 0 -- 良
		g_okNum_[idx]		= 30 -- 可
		g_badNum_[idx]		= 30 -- 不可
		--g_maxComboNum_[idx]	= 0 -- 最大コンボ数
		g_dramrollNum_[idx]	= 0 -- 連打数

		-- g_unreach_[idx]		= false	-- 未到達
	end

	g_maxComboNum_			= 1999  -- 連打数

	-- お題に対する成績
	-- たたけた数
	g_odaiNum_[1][1] = g_goodNum_[1] + g_goodNum_[2] + g_goodNum_[3] + g_okNum_[1] + g_okNum_[2] + g_okNum_[3] + g_dramrollNum_[1] + g_dramrollNum_[2] + g_dramrollNum_[3]
--	g_odaiNum_[1][2] = 
--	g_odaiNum_[1][3] = 
	-- 連打数
	g_odaiNum_[2][1] = g_dramrollNum_[1]
	g_odaiNum_[2][2] = g_dramrollNum_[2]
	g_odaiNum_[2][3] = g_dramrollNum_[3]
	-- 可
	g_odaiNum_[3][1] = g_okNum_[1]
	g_odaiNum_[3][2] = g_okNum_[2]
	g_odaiNum_[3][3] = g_okNum_[3]
	
	--------------------------------------
	-- 演奏オプション(表示に必要な部分のみ設定)
	g_optionSpeed_ = 0				-- オプション：スピード
	g_optionDron_ = false			-- オプション：ドロン
	g_optionReverse_ = false		-- オプション：あべこべ
	g_optionRandomlv_ = 0			-- オプション：ランダム
	g_optionNoteDrawAdjust_ = 0		-- オプション：音符表示位置
	
	--------------------------------------
	-- 報酬関連
	g_isFolder_		= false		-- : true:段位フォルダ追加のお知らせを出す, false:出さない
	g_isShodan_		= false		-- : true:昇段演出を出す, false:出さない
	g_isPresent_	= false		-- : true:ご褒美獲得演出を出す, false:出さない
end

-- デバッグパラメータ4
-- お題数分のパラメータを設定
-- スコア	: すべて0、3曲目は未到達
-- 曲		: 1 : 難易度かんたん☆2, 2 : 難易度ふつう☆4, 3 : 難易度むずかしい☆6
-- お題			
-- 1曲目 : スコア、3曲合計、増えるゲージ
-- 2曲目 : コンボ数、1曲毎、増えるゲージ
-- 3曲目 : 不可、1曲毎、減るゲージ
-- オプション	: すべて設定しない
function SetDummyData_3()
	Debug.PrintString("[DaniResult] SetDummyData_3")

	-- g_odaiClearType_			: お題のクリア条件		: 0: None, 1: 魂(ここでは不使用), 2: 良, 3: 可, 4:不可, 5: コンボ数, 6: 連打数, 7: スコア, 8: たたけた数
	g_odaiClearType_[1] = 0		-- 良
	g_odaiClearType_[2] = 0		-- 可
	g_odaiClearType_[3] = 0		-- 不可

	-- 未到達(trueで未到達)
	g_unreach_[1] = false
	g_unreach_[2] = false
	g_unreach_[3] = false

	---------------------------------------
	-- 曲
	for idx = 1, 3 do
		g_songTitle_[idx]	= "dhero2"			-- 曲名
		g_diffRank_[idx]	= idx*2				-- 難易度
		g_difficulty_[idx]	= idx+1				-- 難易度ランク
	end

	---------------------------------------
	-- お題関連

	g_odaiDani_ = 1		-- 階級
	g_odaiResult_ = 0	-- 合否結果

	-- お題の種類
	-- 0: ALL, 1:1st, 2:2nd, 3:3rd
	g_odaiType_[1]	= 0
	g_odaiType_[2]	= 3
	g_odaiType_[3]	= 3

	-- お題のクリア条件
	-- 0: 良, 1: 可, 2:不可, 3: コンボ数, 4: 連打数, 5: スコア, 6: たたけた数
	-- g_odaiClearType_[1] = 6		-- たたけた数
	-- g_odaiClearType_[2] = 4		-- 連打数
	-- g_odaiClearType_[3] = 1		-- 可

	-- ゲージの種類
	-- 0:0から増えていくゲージ, 1:100から減っていくゲージ
	g_odaiGaugeType_[1]	= 0		
	g_odaiGaugeType_[2] = 0
	g_odaiGaugeType_[3]	= 1

	-- お題達成の値
	-- スコア
	g_odaiBorder_[1][1] = 100
	--g_odaiBorder_[1][2] = 0
	--g_odaiBorder_[1][3] = 0
	-- コンボ数
	g_odaiBorder_[2][1] = 100
	g_odaiBorder_[2][2] = 100
	g_odaiBorder_[2][3] = 100
	-- 不可
	g_odaiBorder_[3][1] = 5
	g_odaiBorder_[3][2] = 10
	g_odaiBorder_[3][3] = 15

	-- お題大成功の値
	-- スコア
	g_odaiGoodBorder_[1][1] = 120
	--g_odaiGoodBorder_[1][2] = 0
	--g_odaiGoodBorder_[1][3] = 0
	-- コンボ数
	g_odaiGoodBorder_[2][1] = 120
	g_odaiGoodBorder_[2][2] = 120
	g_odaiGoodBorder_[2][3] = 120
	-- 不可
	g_odaiGoodBorder_[3][1] = 10
	g_odaiGoodBorder_[3][2] = 15
	g_odaiGoodBorder_[3][3] = 20

	--------------------------------------
	-- 演奏結果

	-- 魂ゲージ
	g_tamashiiGauge_ = 0
	g_tamashiiGaugeValue_	= 0				-- 魂ゲージ実数値
	-- 魂ゲージの成功ライン
	g_gaugeBorder_ = 45
	g_gaugeBorderValue_= 90

	-- 各曲スコア
	for idx = 1, 3 do
		g_totalScore_[idx]	= 0 -- 各曲スコア
		g_goodNum_[idx]		= 0 -- 良
		g_okNum_[idx]		= 30 -- 可
		g_badNum_[idx]		= 30 -- 不可
		--g_maxComboNum_[idx]	= 0 -- 最大コンボ数
		g_dramrollNum_[idx]	= 0 -- 連打数

		-- g_unreach_[idx]		= false	-- 未到達
	end

	g_maxComboNum_			= 1999  -- 連打数

	-- お題に対する成績
	-- たたけた数
	g_odaiNum_[1][1] = g_goodNum_[1] + g_goodNum_[2] + g_goodNum_[3] + g_okNum_[1] + g_okNum_[2] + g_okNum_[3] + g_dramrollNum_[1] + g_dramrollNum_[2] + g_dramrollNum_[3]
--	g_odaiNum_[1][2] = 
--	g_odaiNum_[1][3] = 
	-- 連打数
	g_odaiNum_[2][1] = g_dramrollNum_[1]
	g_odaiNum_[2][2] = g_dramrollNum_[2]
	g_odaiNum_[2][3] = g_dramrollNum_[3]
	-- 可
	g_odaiNum_[3][1] = g_okNum_[1]
	g_odaiNum_[3][2] = g_okNum_[2]
	g_odaiNum_[3][3] = g_okNum_[3]
	
	--------------------------------------
	-- 演奏オプション(表示に必要な部分のみ設定)
	g_optionSpeed_ = 0				-- オプション：スピード
	g_optionDron_ = false			-- オプション：ドロン
	g_optionReverse_ = false		-- オプション：あべこべ
	g_optionRandomlv_ = 0			-- オプション：ランダム
	g_optionNoteDrawAdjust_ = 0		-- オプション：音符表示位置
	
	--------------------------------------
	-- 報酬関連
	g_isFolder_		= false		-- : true:段位フォルダ追加のお知らせを出す, false:出さない
	g_isShodan_		= false		-- : true:昇段演出を出す, false:出さない
	g_isPresent_	= false		-- : true:ご褒美獲得演出を出す, false:出さない
end

-- デバッグ用に仮パラメータの設定
-- スコア		: すべて最大値
-- 曲			: 1 : 難易度かんたん☆2, 2 : 難易度ふつう☆4, 3 : 難易度むずかしい☆6
-- お題			
-- 1曲目 : スコア、3曲合計、増えるゲージ
-- 2曲目 : コンボ数、1曲毎、増えるゲージ
-- 3曲目 : 不可、1曲毎、減るゲージ
-- オプション	: すべて設定する

function SetDummyData_4(result)
	Debug.PrintString("[DaniResult] SetDummyData_4")
	-- SetDummyData_1()

	---------------------------------------
	-- プレイヤー関連
	g_playerDani_ = kDan5kyuu_
	g_arrivalSongCnt_ = 0
	-- お題関連
--	g_odaiDani_ = kDan14dan_		-- お題の階級
	g_odaiDani_ = kDan10dan_		-- お題の階級
	g_odaiResult_ = result		-- 合否結果

	g_dispDani_		= true		-- ネームプレートの段位を表示する。
	g_isFolder_		= true		-- : true:段位フォルダ追加のお知らせを出す, false:出さない
	g_isShodan_		= true		-- : true:昇段演出を出す, false:出さない
	g_isPresent_	= false		-- : true:ご褒美獲得演出を出す, false:出さない
	g_isCongrats_	= true
	g_isBestScore_	= false

	-- 魂ゲージ
	g_tamashiiGauge_ = 50
	g_tamashiiGaugeValue_	= 100				-- 魂ゲージ実数値
	-- 魂ゲージの成功ライン
	g_gaugeBorder_ = 47
	g_gaugeBorderValue_ = 95
end

-- デバッグ用に仮パラメータの設定
-- スコア		: すべて最大値
-- 曲			: 1 : 難易度かんたん☆2, 2 : 難易度ふつう☆4, 3 : 難易度むずかしい☆6
-- お題			
-- 1曲目 : スコア、3曲合計、増えるゲージ
-- 2曲目 : コンボ数、1曲毎、増えるゲージ
-- 3曲目 : 不可、1曲毎、減るゲージ
-- オプション	: すべて設定する

function SetDummyData_5(result)
	Debug.PrintString("[DaniResult] SetDummyData_4")
	-- SetDummyData_1()

	---------------------------------------
	-- プレイヤー関連
	g_playerDani_ = kDan5kyuu_
	-- お題関連
	g_odaiDani_ = kDan14dan_		-- お題の階級 kDan5kyuu_ ~ kDan14dan_
	g_odaiResult_ = result		-- 合否結果

	g_dispDani_		= true		-- ネームプレートの段位を表示する。
	g_isFolder_		= false		-- : true:段位フォルダ追加のお知らせを出す, false:出さない
	g_isShodan_		= true		-- : true:昇段演出を出す, false:出さない
	g_isPresent_	= false		-- : true:ご褒美獲得演出を出す, false:出さない

	-- お題の種類
	-- 0: ALL, 1:1st, 2:2nd, 3:3rd
	g_odaiType_[1]	= 0
	g_odaiType_[2]	= 3
	g_odaiType_[3]	= 3

	-- ゲージの種類
	-- 0:0から増えていくゲージ, 1:100から減っていくゲージ
	g_odaiGaugeType_[1]	= 0
	g_odaiGaugeType_[2] = 0
	g_odaiGaugeType_[3]	= 1

	-- お題達成の値
	-- スコア
	g_odaiBorder_[1][1] = 0
	--g_odaiBorder_[1][2] = 0
	--g_odaiBorder_[1][3] = 0
	-- コンボ数
	g_odaiBorder_[2][1] = 0
	g_odaiBorder_[2][2] = 0
	g_odaiBorder_[2][3] = 0
	-- 不可
	g_odaiBorder_[3][1] = 100
	g_odaiBorder_[3][2] = 100
	g_odaiBorder_[3][3] = 100

	-- お題大成功の値
	-- スコア
	g_odaiGoodBorder_[1][1] = 0
	--g_odaiGoodBorder_[1][2] = 0
	--g_odaiGoodBorder_[1][3] = 0
	-- コンボ数
	g_odaiGoodBorder_[2][1] = 0
	g_odaiGoodBorder_[2][2] = 0
	g_odaiGoodBorder_[2][3] = 0
	-- 不可
	g_odaiGoodBorder_[3][1] = 20
	g_odaiGoodBorder_[3][2] = 20
	g_odaiGoodBorder_[3][3] = 20

	-- お題に対する成績
	-- たたけた数
	g_odaiNum_[1][1] = 0
--	g_odaiNum_[1][2] = 
--	g_odaiNum_[1][3] = 
	-- 連打数
	g_odaiNum_[2][1] = 0
	g_odaiNum_[2][2] = 0
	g_odaiNum_[2][3] = 0
	-- 可
	g_odaiNum_[3][1] = 25
	g_odaiNum_[3][2] = 20
	g_odaiNum_[3][3] = 0
end

