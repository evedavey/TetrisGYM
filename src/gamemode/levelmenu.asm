gameMode_levelMenu:
        lda #NMIEnable
        sta currentPpuCtrl
        jsr updateAudio2
        lda #$7
        sta renderMode
        jsr updateAudioWaitForNmiAndDisablePpuRendering
        jsr disableNmi
.if INES_MAPPER <> 0
        lda #CHRBankSet0
        jsr changeCHRBanks
.endif
        jsr bulkCopyToPpu
        .addr   menu_palette
        jsr copyRleNametableToPpu
        .addr   level_menu_nametable
        lda #$20
        sta tmp1
        lda #$96 ; $6D is OEM position
        sta tmp2
        jsr displayModeText
        jsr showHighScores
        lda linecapFlag
        beq @noLinecapInfo
        jsr levelMenuLinecapInfo
@noLinecapInfo:
        ; render lines when loading screen
        lda #RENDER_LINES
        sta renderFlags
        jsr resetScroll
        jsr waitForVBlankAndEnableNmi
        jsr updateAudioWaitForNmiAndResetOamStaging
        jsr updateAudioWaitForNmiAndEnablePpuRendering
        jsr updateAudioWaitForNmiAndResetOamStaging
        lda #$00
        sta originalY
        sta dropSpeed
@forceStartLevelToRange:
        lda classicLevel
        cmp #$0C
        bcc gameMode_levelMenu_processPlayer1Navigation
        sec
        sbc #$0C
        sta classicLevel
        jmp @forceStartLevelToRange

levelMenuLinecapInfo:
        lda #$20
        sta PPUADDR
        lda #$F5
        sta PPUADDR
        clc
        lda #LINECAP_WHEN_STRING_OFFSET
        adc linecapWhen
        sta stringIndexLookup
        jsr stringBackground

        lda #$21
        sta PPUADDR
        lda #$15
        sta PPUADDR
        clc
        lda #LINECAP_HOW_STRING_OFFSET
        adc linecapHow
        sta stringIndexLookup
        jsr stringBackground

        lda #$20
        sta PPUADDR
        lda #$FA
        sta PPUADDR
        jsr render_linecap_level_lines
        rts

gameMode_levelMenu_processPlayer1Navigation:
        ; this copying is an artefact of the original
        lda newlyPressedButtons_player1
        sta newlyPressedButtons

        lda levelControlMode
        cmp #4
        bne @notClearingHighscores
        lda newlyPressedButtons_player1
        cmp #BUTTON_START
        bne @notClearingHighscores
        lda #$01
        sta soundEffectSlot1Init
        lda #0
        sta levelControlMode
        jsr resetScores
.if SAVE_HIGHSCORES
        jsr detectSRAM
        beq @notResettingSavedScores
        jsr resetSavedScores
@notResettingSavedScores:
.endif
        jsr updateAudioWaitForNmiAndResetOamStaging
        jmp gameMode_levelMenu
@notClearingHighscores:

        jsr levelControl
        jsr levelMenuRenderHearts
        jsr levelMenuRenderReady

        lda levelControlMode
        cmp #2
        bcs levelMenuCheckGoBack

levelMenuCheckStartGame:
        lda newlyPressedButtons_player1
        cmp #BUTTON_START
        bne levelMenuCheckGoBack
        lda levelControlMode
        cmp #1 ; custom
        bne @normalLevel
        lda customLevel
        sta startLevel
        jmp @startGame
@normalLevel:
        lda heldButtons_player1
        and #BUTTON_A
        beq @noA
        ; Handle A button for different positions
        lda classicLevel
        cmp #$05  ; Position 5 is level 24
        beq @add1
        cmp #$0B  ; Position 11 is level 39
        beq @add99
        ; Positions 0-4, 6-10 are levels 0-9, add 10
        ldx classicLevel
        lda levelValueTable,x
        clc
        adc #$0A
        sta startLevel
        jmp @startGame
@add1:
        lda #$19  ; 24 + 1 = 25
        sta startLevel
        jmp @startGame
@add99:
        lda #$8A  ; 39 + 99 = 138
        sta startLevel
        jmp @startGame
@noA:
        ldx classicLevel
        lda levelValueTable,x
        sta startLevel
@startGame:
        ; lda startLevel
        ldy practiseType
        cpy #MODE_MARATHON
        bne @noLevelModification
        ldy marathonModifier
        cpy #2 ; marathon modes 2 & 4 starts at level 0
        beq @startAtZero
        cpy #4
        bne @noLevelModification
@startAtZero:
        lda #0
@noLevelModification:
        sta levelNumber
        lda #$00
        sta gameModeState
        lda #$02
        sta soundEffectSlot1Init
        jsr makeNotReady
        inc gameMode
        rts

levelMenuCheckGoBack:
.if !NO_MENU
        lda newlyPressedButtons_player1
        cmp #BUTTON_B
        bne @continue
        lda #$02
        sta soundEffectSlot1Init
        ; jsr makeNotReady ; not needed, done on gametype screen
        dec gameMode
        rts
.endif
@continue:

shredSeedAndContinue:
        ; seed shredder
@chooseRandomHole_player1:
        ldx #rng_seed
        jsr generateNextPseudorandomNumber
        lda rng_seed
        and #$0F
        cmp #$0C
        bpl @chooseRandomHole_player1
@chooseRandomHole_player2:
        ldx #rng_seed
        jsr generateNextPseudorandomNumber
        lda rng_seed
        and #$0F
        cmp #$0C
        bpl @chooseRandomHole_player2

        jsr updateAudioWaitForNmiAndResetOamStaging
        jmp gameMode_levelMenu_processPlayer1Navigation

makeNotReady:
        lda heartsAndReady
        and #$F
        sta heartsAndReady
        rts

levelControl:
        branchTo levelControlMode, \
            levelControlNormal, \
            levelControlCustomLevel, \
            levelControlHearts, \
            levelControlClearHighScores, \
            levelControlClearHighScoresConfirm

levelControlClearHighScores:
        lda #$20
        sta spriteXOffset
        lda #$C8
        sta spriteYOffset
        lda #$C
        sta spriteIndexInOamContentLookup
        jsr stringSprite

        jsr highScoreClearUpOrLeave

        lda newlyPressedButtons_player1
        cmp #BUTTON_START
        bne @notStart
        lda #$01
        sta soundEffectSlot1Init
        lda #4
        sta levelControlMode
@notStart:
        rts

levelControlClearHighScoresConfirm:
        lda #$20
        sta spriteXOffset
        lda #$C8
        sta spriteYOffset
        lda #$D
        sta spriteIndexInOamContentLookup
        jsr stringSprite

highScoreClearUpOrLeave:
        lda newlyPressedButtons_player1
        cmp #BUTTON_B
        bne @notB
        lda #$0
        sta levelControlMode
@notB:
        lda newlyPressedButtons
        cmp #BUTTON_UP
        bne @ret
        lda #$01
        sta soundEffectSlot1Init
        lda #$2
        sta levelControlMode
@ret:
        rts


levelControlCustomLevel:
        jsr handleReadyInput
        lda frameCounter
        and #$03
        beq @indicatorEnd
        lda #$4E
        sta spriteYOffset
        lda #$B0
        sta spriteXOffset
        lda #$21
        sta spriteIndexInOamContentLookup
        jsr loadSpriteIntoOamStaging
@indicatorEnd:

        ; lda #BUTTON_RIGHT
        ; jsr menuThrottle
        ; beq @checkUpPressed
        ; clc
        ; lda customLevel
        ; adc #$A
        ; sta customLevel
        ; jsr @changeLevel
; @checkUpPressed:
        lda #BUTTON_UP
        jsr menuThrottle
        beq @checkDownPressed
        inc customLevel
        jsr @changeLevel
@checkDownPressed:
        lda #BUTTON_DOWN
        jsr menuThrottle
        beq @checkLeftPressed
        dec customLevel
        jsr @changeLevel
@checkLeftPressed:

        lda newlyPressedButtons
        cmp #BUTTON_LEFT
        bne @ret
        lda #$01
        sta soundEffectSlot1Init
        lda #$0
        sta levelControlMode
@ret:
        rts

@changeLevel:
        lda #$1
        sta soundEffectSlot1Init
        lda renderFlags
        ora #RENDER_LINES
        sta renderFlags
        rts

levelControlHearts:
MAX_HEARTS := 7
        lda #BUTTON_LEFT
        jsr menuThrottle
        beq @checkRightPressed
        lda heartsAndReady
        and #$F
        beq @checkRightPressed
        lda #$01
        sta soundEffectSlot1Init
        dec heartsAndReady
        jsr @changeHearts
@checkRightPressed:
        lda #BUTTON_RIGHT
        jsr menuThrottle
        beq @checkUpPressed
        lda heartsAndReady
        and #$F
        cmp #MAX_HEARTS
        bpl @checkUpPressed
        inc heartsAndReady
        jsr @changeHearts
@checkUpPressed:

        ; to clear mode
        lda newlyPressedButtons
        cmp #BUTTON_DOWN
        bne @notClearMode
        lda #$01
        sta soundEffectSlot1Init
        lda #$3
        sta levelControlMode
@notClearMode:

        ; to normal mode
        lda newlyPressedButtons
        cmp #BUTTON_UP
        bne @ret
        lda #$01
        sta soundEffectSlot1Init
        lda #$0
        sta levelControlMode
@ret:
        rts

@changeHearts:
        lda #$01
        sta soundEffectSlot1Init
        rts

handleReadyInput:
        lda newlyPressedButtons
        cmp #BUTTON_SELECT
        bne @notSelect
        lda #$01
        sta soundEffectSlot1Init
        lda heartsAndReady
        eor #$80
        sta heartsAndReady
@notSelect:
        rts

levelControlNormal:
        jsr handleReadyInput
        ; normal ctrl
        lda newlyPressedButtons
        cmp #BUTTON_RIGHT
        bne @checkLeftPressed
        lda #$01
        sta soundEffectSlot1Init
        lda classicLevel
        cmp #$0B
        beq @toCustomLevel
        inc classicLevel
@checkLeftPressed:
        lda newlyPressedButtons
        cmp #BUTTON_LEFT
        bne @checkDownPressed
        lda #$01
        sta soundEffectSlot1Init
        lda classicLevel
        beq @checkDownPressed
        dec classicLevel
@checkDownPressed:
        lda newlyPressedButtons
        cmp #BUTTON_DOWN
        bne @checkUpPressed
        lda #$01
        sta soundEffectSlot1Init
        lda classicLevel
        cmp #$06
        bpl @toHearts
        clc
        adc #$06
        sta classicLevel
        jmp @checkUpPressed

@toHearts:
        jsr makeNotReady
        inc levelControlMode
@toCustomLevel:
        inc levelControlMode
        rts

@checkUpPressed:
        lda newlyPressedButtons
        cmp #BUTTON_UP
        bne @checkAPressed
        lda #$01
        sta soundEffectSlot1Init
        lda classicLevel
        cmp #$06
        bmi @checkAPressed
        sec
        sbc #$06
        sta classicLevel
        jmp @checkAPressed

@checkAPressed:
        lda frameCounter
        and #$03
        beq @ret
; @showSelectionLevel:
        ldx classicLevel
        lda levelToSpriteYOffset,x
        sta spriteYOffset
        lda #$00
        sta spriteIndexInOamContentLookup
        ldx classicLevel
        lda levelToSpriteXOffset,x
        sta spriteXOffset
        jsr loadSpriteIntoOamStaging
@ret:
        rts

levelMenuRenderHearts:
        lda #$1E
        sta spriteIndexInOamContentLookup
        lda #$7A
        sta spriteYOffset
        lda #$38
        sta spriteXOffset
        lda heartsAndReady
        and #$F
        sta tmpZ
@heartLoop:
        lda tmpZ
        beq @heartEnd
        jsr loadSpriteIntoOamStaging
        lda spriteXOffset
        adc #$A
        sta spriteXOffset
        dec tmpZ
        bcc @heartLoop
@heartEnd:

        lda levelControlMode
        cmp #2
        bne @skipCursor
        lda frameCounter
        and #$03
        beq @skipCursor
        lda #$1F
        sta spriteIndexInOamContentLookup
        jsr loadSpriteIntoOamStaging
@skipCursor:
        rts

levelMenuRenderReady:
        lda heartsAndReady
        and #$F0
        beq @notReady
        lda #$5B
        sta spriteYOffset
        lda #$94
        sta spriteXOffset
        lda #$20
        sta spriteIndexInOamContentLookup
        jsr loadSpriteIntoOamStaging
@notReady:
        rts

levelValueTable:
        .byte   $00,$01,$02,$03,$04,$18,$05,$06,$07
        .byte   $08,$09,$27

levelToSpriteYOffset:
        .byte   $53,$53,$53,$53,$53,$53,$63,$63,$63
        .byte   $63,$63,$63
levelToSpriteXOffset:
        .byte   $34,$44,$54,$64,$74,$84,$34,$44,$54
        .byte   $64,$74,$84
musicSelectionTable:
        .byte   $03,$04,$05,$FF,$06,$07,$08,$FF