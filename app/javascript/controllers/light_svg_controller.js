import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["svg", "light"]
  static values = {
    lightDefinitions: Array,
    userLights: Array,
    currentIndex: { type: Number, default: 0 },
    startX: { type: Number, default: 0 },
    startY: { type: Number, default: 0 },
    startTime: { type: Number, default: 0 }
  }

  connect() {
    this.isInteractionDisabled = false
    this.hasShownAccumulatedLights = false
    this.initFloatingLightsManager()
    this.setupTouchEvents()
    this.updateLightColor()
    // 初回読み込み時は既存の感情を表示しない
    // this.loadExistingLights()
  }

  disconnect() {
    // クリーンアップ
    if (this.floatingLightsManager) {
      this.floatingLightsManager.cleanup()
    }
  }

  initFloatingLightsManager() {
    this.floatingLightsManager = {
      container: null,
      lights: [],
      accumulatedLights: [],

      init() {
        this.container = document.getElementById('floating-lights-container')
        if (!this.container) {
          console.error('floating-lights-container not found')
          return false
        }
        return true
      },

      cleanup() {
        if (this.container) {
          this.container.innerHTML = ''
          this.lights = []
          this.accumulatedLights = []
        }
      },


      // 蓄積されたライトを同心円状にフェードイン表示
      showAccumulatedLights(userLights, isRippleEffect = false) {
        if (!this.container || !userLights) return

        // 中心点（画面中央）
        const centerX = window.innerWidth / 2
        const centerY = window.innerHeight / 2

        userLights.forEach((userLight, index) => {
          if (userLight.amount > 0) {
            const color = `rgba(${userLight.light_definition.r}, ${userLight.light_definition.g}, ${userLight.light_definition.b}, ${userLight.light_definition.a / 255})`
            
            for (let i = 0; i < userLight.amount; i++) {
              const light = document.createElement('div')
              light.className = `accumulated-light ${isRippleEffect ? 'ripple-light' : ''}`
              light.style.background = color

              // 同心円状に配置
              const radius = 100 + (i * 50) // 中心から100px開始、50pxずつ離れる
              const angle = (index * (360 / userLights.length)) + (i * 15) // 種類ごとに角度オフセット
              const radian = (angle * Math.PI) / 180

              const x = centerX + Math.cos(radian) * radius
              const y = centerY + Math.sin(radian) * radius

              light.style.left = x + 'px'
              light.style.top = y + 'px'
              light.style.width = '40px'
              light.style.height = '40px'

              // 順次フェードイン（波紋効果）
              light.style.animationDelay = `${(i + index) * 0.1}s`

              this.container.appendChild(light)
              this.accumulatedLights.push(light)
            }
          }
        })
      },

      // 既存のlightを背景に配置（遠方表現）
      loadExistingLights(userLights) {
        if (!this.container || !userLights) return

        userLights.forEach(userLight => {
          if (userLight.amount > 0) {
            const color = `rgba(${userLight.light_definition.r}, ${userLight.light_definition.g}, ${userLight.light_definition.b}, ${userLight.light_definition.a / 255})`
            this.addLight(color, userLight.amount)
          }
        })
      },

      // 新しいlightを背景に追加（遠方表現）
      addLight(color, amount = 1) {
        if (!this.container) return

        for (let i = 0; i < amount; i++) {
          const light = document.createElement('div')
          light.className = 'floating-light distant'
          light.style.background = color

          // 遠方のランダムな位置に配置（画面の端寄り）
          const margin = 100
          const x = margin + Math.random() * (window.innerWidth - 2 * margin)
          const y = margin + Math.random() * (window.innerHeight - 2 * margin)
          light.style.setProperty('--start-x', x + 'px')
          light.style.setProperty('--start-y', y + 'px')
          light.style.left = x + 'px'
          light.style.top = y + 'px'

          this.container.appendChild(light)
          this.lights.push(light)
        }
      }
    }

    // 初期化
    if (!this.floatingLightsManager.init()) {
      console.error('Failed to initialize floating lights manager')
    }
  }

  setupTouchEvents() {
    this.svgTarget.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
    this.svgTarget.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
    this.svgTarget.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false })
  }

  handleTouchStart(event) {
    event.preventDefault()
    // event.touches[0]はタッチの座標を取得するので、これを使ってstartXValueとstartYValueを設定する
    const touch = event.touches[0]
    this.startXValue = touch.clientX
    this.startYValue = touch.clientY
    // startTimeValueはタッチ開始時の時刻を取得する。時間を取得することで、フリックやスワイプの判定に使用する。具体的には、フリックの場合は、タッチ開始からの経過時間を取得することで、フリックの速度を判定する。速度の調整は、deltaTimeの値の条件を調整することで行う。
    this.startTimeValue = Date.now()
  }

  handleTouchMove(event) {
    event.preventDefault()
  }

  handleTouchEnd(event) {
    event.preventDefault()
    const touch = event.changedTouches[0]
    const deltaX = touch.clientX - this.startXValue
    const deltaY = touch.clientY - this.startYValue
    const deltaTime = Date.now() - this.startTimeValue

    // フリック判定（水平方向の移動が大きい場合）
    // 50はフリックの最小移動距離、300はフリックの最大時間。これらの値を調整することで、フリックの速度を調整する。Math.abs(deltaX)はdeltaXの絶対値を取得する。離した距離が50より大きい場合はフリックと判定する。deltaTimeはタッチ開始からの経過時間を取得する。この時間が300ミリ秒より小さい場合はフリックと判定する。話さない場合は
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50 && deltaTime < 300) {
      this.handleFlick(deltaX > 0 ? 'right' : 'left')
    }
    // スワイプ判定（垂直方向の移動が大きい場合）
    else if (Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > 50) {
      this.handleSwipe(deltaY > 0 ? 'down' : 'up')
    }
  }

  handleFlick(direction) {
    // インタラクション無効化中は何もしない
    if (this.isInteractionDisabled) {
      return
    }

    if (direction === 'left') {
      this.nextLight()
    } else {
      this.previousLight()
    }
  }

  handleSwipe(direction) {
    // インタラクション無効化中は何もしない
    if (this.isInteractionDisabled) {
      return
    }

    if (direction === 'up') {
      this.executeAction()
    }
  }

  nextLight() {
    this.currentIndexValue = (this.currentIndexValue + 1) % this.lightDefinitionsValue.length
    this.updateLightColor()
  }

  previousLight() {
    this.currentIndexValue = this.currentIndexValue === 0
      ? this.lightDefinitionsValue.length - 1
      : this.currentIndexValue - 1
    this.updateLightColor()
  }

  executeAction() {
    // インタラクション無効化中は何もしない
    if (this.isInteractionDisabled) {
      return
    }

    const currentLight = this.lightDefinitionsValue[this.currentIndexValue]
    const color = `rgba(${currentLight.r}, ${currentLight.g}, ${currentLight.b}, ${currentLight.a / 255})`

    // インタラクションを無効化
    this.disableInteraction()

    // SVGライトオブジェクト自体を投射
    this.projectSvgLight(color)

    // サーバーにLight増加リクエストを送信
    fetch('/api/lights/increment', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        light_key: currentLight.key
      })
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          // userLightsValueを更新
          this.updateUserLightsValue(currentLight.key)
        }
      })
      .catch(error => {
        console.error('Error:', error)
        // エラー時もインタラクションを再有効化
        this.enableInteraction()
      })
  }

  // SVGライトオブジェクト自体を投射
  projectSvgLight(color) {
    // 現在の位置を記録
    const rect = this.element.getBoundingClientRect()
    const startX = rect.left
    const startY = rect.top

    // 固定の終点（画面中央上部）
    const endX = window.innerWidth / 2 - 100 // SVGの幅の半分を引く
    const endY = 50 // 画面上部から50px

    // アニメーション開始前の位置を設定
    this.element.style.left = startX + 'px'
    this.element.style.top = startY + 'px'
    this.element.style.bottom = 'auto'
    this.element.style.transform = 'translateX(0)'

    // アニメーションクラスを追加
    this.element.classList.add('light-container-projecting')

    // アニメーション終了時の処理
    const animationEndHandler = () => {
      this.element.removeEventListener('animationend', animationEndHandler)
      
      // 最終位置に固定
      this.element.classList.remove('light-container-projecting')
      this.element.style.left = endX + 'px'
      this.element.style.top = endY + 'px'
      this.element.style.transform = 'translate(0, 0) scale(0.15)'
      this.element.style.opacity = '0.5'

      // 投射完了後の処理
      setTimeout(() => {
        // 背景にライトを追加
        if (this.floatingLightsManager) {
          this.floatingLightsManager.addLight(color, 1)
        }

        // 蓄積ライトを表示
        if (!this.hasShownAccumulatedLights) {
          this.floatingLightsManager.showAccumulatedLights(this.userLightsValue, true)
          this.hasShownAccumulatedLights = true
        }

        // SVGライトを元の位置に戻す
        this.resetSvgLight()
        
        // インタラクションを再有効化
        this.enableInteraction()
      }, 300)
    }

    this.element.addEventListener('animationend', animationEndHandler)
  }

  // SVGライトを元の位置に戻す
  resetSvgLight() {
    // アニメーションクラスを削除
    this.element.classList.remove('light-container-projecting')
    
    // 元の位置に戻す
    this.element.style.left = '50%'
    this.element.style.bottom = '5px'
    this.element.style.top = 'auto'
    this.element.style.transform = 'translateX(-50%)'
    this.element.style.opacity = '1'

    // フェードインアニメーション
    this.lightTarget.style.opacity = '0'
    setTimeout(() => {
      this.lightTarget.style.opacity = '1'
      this.lightTarget.style.transition = 'opacity 0.5s ease-in'
    }, 100)
  }

  // インタラクション無効化
  disableInteraction() {
    this.isInteractionDisabled = true
    this.element.classList.add('interaction-disabled')
  }

  // インタラクション有効化
  enableInteraction() {
    this.isInteractionDisabled = false
    this.element.classList.remove('interaction-disabled')
  }


  // userLightsValueを更新
  updateUserLightsValue(lightKey) {
    const existingLight = this.userLightsValue.find(light => 
      light.light_definition.key === lightKey
    )
    
    if (existingLight) {
      existingLight.amount += 1
    } else {
      const lightDef = this.lightDefinitionsValue.find(def => def.key === lightKey)
      if (lightDef) {
        this.userLightsValue.push({
          amount: 1,
          light_definition: lightDef
        })
      }
    }
  }

  updateLightColor() {
    const currentLight = this.lightDefinitionsValue[this.currentIndexValue]
    const color = `rgba(${currentLight.r}, ${currentLight.g}, ${currentLight.b}, ${currentLight.a / 255})`

    // SVGのグラデーションを更新
    const gradient = this.svgTarget.querySelector('#lightGrad')
    const stops = gradient.querySelectorAll('stop')

    stops[0].setAttribute('stop-color', color)
    stops[0].setAttribute('stop-opacity', '1.0')
    stops[1].setAttribute('stop-color', color)
    stops[1].setAttribute('stop-opacity', '0.6')
    stops[2].setAttribute('stop-color', color)
    stops[2].setAttribute('stop-opacity', '0')
  }

  triggerLightAnimation() {
    // アニメーションをリセットして再実行
    this.lightTarget.style.animation = 'none'
    this.lightTarget.offsetHeight // リフローを強制

    // 新しいアニメーションを設定
    this.lightTarget.style.animation = 'float 0.8s ease-in-out infinite'

    // パルスアニメーションが終了したら通常のアニメーションに戻す
    setTimeout(() => {
      this.lightTarget.style.animation = 'float 0.8s ease-in-out infinite'
    }, 500)
  }

  loadExistingLights() {
    if (this.floatingLightsManager && this.userLightsValue) {
      this.floatingLightsManager.loadExistingLights(this.userLightsValue)
    }
  }
} 