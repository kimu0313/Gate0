# GATE 0 — PA announcement voice generator (Windows SAPI TTS).
# Usage (from project root):  powershell -ExecutionPolicy Bypass -File tools\gen_voice.ps1
# Output: assets\audio\voice\*.wav  (22.05 kHz 16-bit mono)
# Godot routes these through the "PA" audio bus (reverb + band-pass) so the raw TTS reads as a terminal PA system.

Add-Type -AssemblyName System.Speech

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "assets\audio\voice"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$KO = "Microsoft Heami Desktop"
$EN = "Microsoft Zira Desktop"

# id = @(voice, rate(-10..10), text)
$lines = [ordered]@{
	# 표준 테스트 방송 (정상 기준) — 근무 수칙 p.4 에 문안이 실려 있다.
	"pa_test_normal_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 감사합니다.")
	"pa_test_normal_en"        = @($EN, -1, "Attention please. Facility inspection is currently in progress in this terminal. Authorized personnel only. Thank you.")
	# 이상 변형: 단어 하나만 바뀐다.
	"pa_test_anom_a_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 탑승 수속이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 감사합니다.")
	"pa_test_anom_b_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 승객 외에는 출입을 삼가 주시기 바랍니다. 감사합니다.")
	"pa_test_anom_c_ko"        = @($KO, -1, "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 기다리고 있겠습니다.")
	# 0편 관련
	"pa_flight0_move_ko"       = @($KO, -2, "영편 승객께서는 출국장으로 이동해 주시기 바랍니다.")
	"pa_flight0_move_en"       = @($EN, -2, "Passengers of flight zero, please proceed to the departure area.")
	"pa_flight0_checkin_ko"    = @($KO, -2, "영편 탑승 수속을 시작합니다. 승객 여러분께서는 영번 게이트로 이동해 주시기 바랍니다.")
	"pa_last_baggage_ko"       = @($KO, -2, "마지막 수하물이 도착했습니다.")
	"pa_one_passenger_ko"      = @($KO, -2, "승객 한 분이 탑승 수속을 마쳤습니다.")
	"pa_passenger_confirmed_ko"= @($KO, -3, "승객 확인되었습니다.")
	"pa_boarding_complete_ko"  = @($KO, -3, "탑승 수속이 완료되었습니다. 안녕히 가십시오.")
	"pa_final_call_ko"         = @($KO, -2, "영편 최종 탑승 안내입니다. 아직 탑승하지 않으신 승객께서는, 지금 즉시 영번 게이트로 오시기 바랍니다.")
	"pa_final_call_en"         = @($EN, -2, "This is the final boarding call for flight zero. Remaining passenger, please proceed to gate zero immediately.")
	"pa_call_generic_ko"       = @($KO, -3, "승객님. 승객님. 영번 게이트로 오시기 바랍니다. 기다리고 있습니다.")
	"pa_3am_ko"                = @($KO, -2, "현재 시각, 새벽 세 시입니다. 영편 탑승을 마감합니다.")
	"pa_destination_home_ko"   = @($KO, -3, "목적지는, 집입니다.")
	# 낮 / 엔딩
	"pa_welcome_ko"            = @($KO, -1, "서해국제공항에 오신 것을 환영합니다. 즐거운 여행 되십시오.")
	"pa_welcome_en"            = @($EN, -1, "Welcome to Seohae International Airport. Have a pleasant journey.")
	"pa_arrived_ko"            = @($KO, -3, "도착했습니다.")
	"pa_grand_opening_ko"      = @($KO, -1, "서해국제공항이 오늘 정식 개장합니다. 승객 여러분을 진심으로 환영합니다.")
	"pa_flight0_boarding_en"   = @($EN, -2, "Flight zero is now boarding.")
	"pa_next_worker_ko"        = @($KO, -3, "안내 말씀 드립니다. 다음 근무자께서는, 근무 수칙을 꼭 지켜 주시기 바랍니다.")
}

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)

foreach ($id in $lines.Keys) {
	$voice, $rate, $text = $lines[$id]
	$path = Join-Path $outDir ($id + ".wav")
	try {
		$synth.SelectVoice($voice)
	} catch {
		Write-Warning "voice '$voice' missing, using default for $id"
	}
	$synth.Rate = $rate
	$synth.Volume = 100
	$synth.SetOutputToWaveFile($path, $fmt)
	$synth.Speak($text)
	$synth.SetOutputToNull()
	Write-Output ("{0,-28} {1,8} bytes" -f $id, (Get-Item $path).Length)
}
$synth.Dispose()
