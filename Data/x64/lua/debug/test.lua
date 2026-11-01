-- グローバル変数
testGlobalNum = 100000
testGlobalString = "myo-!"

testGlobalSeqNo = 0
testGlobalCounter = 0

-- フレーム待ち
function Sync(waitframe)
	coroutine.yield(waitframe);
end

-- 初期化
function Initialize()
	testGlobalSeqNo = 0
	testGlobalCounter = 0
end


-- メイン関数的なもの、TaikoのCプログラムから毎フレーム呼ばれる
function MainProc()
--	print(testGlobalNum)

	if(testGlobalSeqNo == 0) then
		testGlobalCounter = testGlobalCounter + 1
		if(testGlobalCounter > 30) then
			testGlobalSeqNo = testGlobalSeqNo + 1
			testGlobalCounter = 0
		end
	end

--	testFontPrint("hoge-------------------日本語...........もそもそ.......\n")
--	Font.testPrint("hoge-------------------日本語...........もそもそ.......\n")

--	Sync(1)

--	testFontPrint("2フレーム目・・・\n")
--	Font.testPrint("2フレーム目・・・\n")

--	Sync(60);

--	testFontPrint("６０フレーム目・・・\n")
--	Font.testPrint("６０フレーム目・・・\n")

--	Sync(120);

--[[
	Font.Print(0,0,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(10,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(20,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(30,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(40,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(50,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(51,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(52,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(53,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(54,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(55,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(56,10,1.0,1.0,1.0,1.0,"TEST STRING")
	Sync(1)
	Font.Print(57,10,1.0,1.0,1.0,1.0,"TEST STRING")
]]

	-- ローカル変数で覚えておく
	local menuFunc = Menu_0

--	for idx = 0,120,1 do
	-- 無限ループ
	while true do
		local nextFunc = menuFunc()
		if(nextFunc ~= nil) then
			menuFunc = nextFunc
		end
		-- １フレーム待ち
		Sync(1)
	end

--	print(testGlobalSeqNo)
--	print(testGlobalCounter)

end

function Menu_0()
	local nextMenu = nil

	local menuIndex = 0

	for key,value in pairs(InputTest) do
		print(key,' = ',value)
	end

		print("")

	while true do
		-- ←
--		if(Input.IsTriggered(TaikoInput_Key_L_L) == true) then
--		if(Input.IsTriggered(InputTest.KeyType_L_L) == true) then
		if(InputTest.IsTriggered(InputTest.KeyType_L_L) == true) then
			menuIndex = menuIndex - 1
		end
		-- →
		if(Input.IsTriggered(TaikoInput_Key_L_R) == true) then
			menuIndex = menuIndex + 1
		end
		-- ×
		if(Input.IsTriggered(TaikoInput_Key_R_D) == true) then
			if(menuIndex == 0) then
				nextMenu = Menu_1
				break
			end

			if(InputTest.KeyType_L_R ~= TaikoInput_Key_L_R) then
				InputTest.KeyType_L_R = TaikoInput_Key_L_R
			else
				InputTest.KeyType_L_R = InputTest.KeyType_L_R + 10
			end

--			InputTest["hoge"] = "myo---"
			InputTest.Hogee = "mmmm"
--			InputTest.KeyType_L_R = "aaaa"

--			InputTest.KeyType_L_R = nil

--			InputTest.KeyType_L_R = "aaaa"

--NG			InputTest.0 = "0000"

			InputTest[100] = "1000"

			for key,value in pairs(InputTest) do
				print(key,' = ',value)
			end
		end

		if(menuIndex < 0) then
			menuIndex = 2
		end
		if(menuIndex >= 3) then
			menuIndex = 0
		end

		local col1 = 1.0
		local col2 = 2.0
		local col3 = 3.0
		if(menuIndex == 0) then
			col1 = 0.0
		end
		if(menuIndex == 1) then
			col2 = 0.0
		end
		if(menuIndex == 2) then
			col3 = 0.0
		end

		Font.Print(30,50,1.0,1.0,1.0,1.0," - MENU 0 - ")
		Font.Print(10,80,1.0,col1,1.0,1.0,"MENU 1")
		Font.Print(10,110,1.0,col2,1.0,1.0,"MENU 2")
		Font.Print(10,140,1.0,col3,1.0,1.0,"MENU 3")

		if(InputTest.KeyType_L_R ~= TaikoInput_Key_L_R) then
			Font.Print(10,200,1.0,col3,1.0,1.0,"LR change...")
		end

		Font.Print(10,250,1.0,col3,1.0,1.0,tostring(InputTest.KeyType_L_R))
--		Font.Print(10,280,1.0,col3,1.0,1.0,tostring(InputTest.__index.KeyType_L_R))
		Font.Print(10,310,1.0,col3,1.0,1.0,tostring(InputTest.Hogee))

--		Font.Print(10,200,1.0,col3,1.0,1.0,"MENU 3")



		-- １フレーム待ち
		Sync(1)
	end

	return nextMenu
end

function Menu_1()
	local nextMenu = nil

	local menuIndex = 0

	while true do
		-- ←
		if(Input.IsTriggered(TaikoInput_Key_L_L) == true) then
			menuIndex = menuIndex - 1
		end
		-- →
		if(Input.IsTriggered(TaikoInput_Key_L_R) == true) then
			menuIndex = menuIndex + 1
		end
		-- ×
		if(Input.IsTriggered(TaikoInput_Key_R_D) == true) then
			if(menuIndex == 0) then
				nextMenu = Command_1
				break
			end
			if(menuIndex == 2) then
				nextMenu = Menu_0
				break
			end
		end

		if(menuIndex < 0) then
			menuIndex = 2
		end
		if(menuIndex >= 3) then
			menuIndex = 0
		end

		local col1 = 1.0
		local col2 = 2.0
		local col3 = 3.0
		if(menuIndex == 0) then
			col1 = 0.0
		end
		if(menuIndex == 1) then
			col2 = 0.0
		end
		if(menuIndex == 2) then
			col3 = 0.0
		end

		Font.Print(30,50,1.0,1.0,1.0,1.0," - MENU 1 - ")
		Font.Print(10,80,1.0,col1,1.0,1.0,"COMMAND 1")
		Font.Print(10,110,1.0,col2,1.0,1.0,"COMMAND 2")
		Font.Print(10,140,1.0,col3,1.0,1.0,"EXIT")


		-- １フレーム待ち
		Sync(1)
	end

	return nextMenu
end

function Command_1()
	local nextMenu = nil

	local speedX = 5
	local posX = 10
	local colR = 0.0

	while true do
		-- ←で速度減
		if(Input.IsTriggered(TaikoInput_Key_L_L) == true) then
			speedX = speedX - 1
		end
		-- →で速度増
		if(Input.IsTriggered(TaikoInput_Key_L_R) == true) then
			speedX = speedX + 1
		end
		-- ×
		if(Input.IsTriggered(TaikoInput_Key_R_D) == true) then
			nextMenu = Menu_1
			break
		end

		-- 文字列表示
		Font.Print(posX,10,1.0,colR,1.0,1.0,"TEST STRING")

		-- 位置と色を更新
		posX = posX + speedX
		if(posX > 1500.0) then
			posX = 10
		end
		if(posX < 10) then
			posX = 1500
		end

		colR = colR + 0.1
		if(colR > 1.0) then
			colR = 0.0
		end

		-- １フレーム待ち
		Sync(1)
	end

	return nextMenu
end
