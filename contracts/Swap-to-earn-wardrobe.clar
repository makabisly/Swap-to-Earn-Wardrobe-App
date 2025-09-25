;; title: Swap-to-earn-wardrobe

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)
(impl-trait .sip-010-trait.sip-010-trait)

(define-fungible-token swap-reward)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-item-not-found (err u102))
(define-constant err-swap-not-found (err u103))
(define-constant err-invalid-swap-status (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-user-not-registered (err u106))
(define-constant err-item-already-exists (err u107))
(define-constant err-swap-already-exists (err u108))
(define-constant err-invalid-style-score (err u109))

(define-constant style-match-perfect u100)
(define-constant style-match-excellent u80)
(define-constant style-match-good u60)
(define-constant style-match-fair u40)
(define-constant style-bonus-multiplier u2)
(define-constant min-style-score u0)
(define-constant max-style-score u100)

(define-data-var token-name (string-ascii 32) "SwapReward")
(define-data-var token-symbol (string-ascii 10) "SWR")
(define-data-var token-decimals uint u6)
(define-data-var total-supply uint u0)
(define-data-var next-item-id uint u1)
(define-data-var next-swap-id uint u1)
(define-data-var reward-per-swap uint u100000000)

(define-map users principal {
    username: (string-ascii 50),
    reputation: uint,
    total-swaps: uint,
    joined-at: uint
})

(define-map clothing-items uint {
    owner: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    size: (string-ascii 20),
    condition: (string-ascii 20),
    image-url: (string-ascii 200),
    available: bool,
    created-at: uint
})

(define-map swaps uint {
    initiator: principal,
    responder: principal,
    initiator-item: uint,
    responder-item: uint,
    status: (string-ascii 20),
    created-at: uint,
    completed-at: (optional uint)
})

(define-map user-items principal (list 100 uint))
(define-map balances principal uint)

(define-map item-style-attributes uint {
    style-type: (string-ascii 30),
    color-palette: (string-ascii 30),
    formality-level: uint,
    season: (string-ascii 20),
    trend-score: uint
})

(define-map user-style-preferences principal {
    preferred-style: (string-ascii 30),
    color-harmony: uint,
    versatility-score: uint,
    eco-conscious-rating: uint
})

(define-map swap-style-scores uint {
    compatibility-score: uint,
    bonus-earned: uint,
    match-category: (string-ascii 20)
})

(define-data-var total-style-matches uint u0)
(define-data-var perfect-matches uint u0)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) err-not-authorized)
        (asserts! (<= amount (ft-get-balance swap-reward sender)) err-insufficient-balance)
        (try! (ft-transfer? swap-reward amount sender recipient))
        (print memo)
        (ok true)))

(define-read-only (get-name)
    (ok (var-get token-name)))

(define-read-only (get-symbol)
    (ok (var-get token-symbol)))

(define-read-only (get-decimals)
    (ok (var-get token-decimals)))

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance swap-reward who)))

(define-read-only (get-total-supply)
    (ok (ft-get-supply swap-reward)))

(define-read-only (get-token-uri)
    (ok none))

(define-public (register-user (username (string-ascii 50)))
    (let ((user-data {
        username: username,
        reputation: u0,
        total-swaps: u0,
        joined-at: stacks-block-height
    }))
    (asserts! (is-none (map-get? users tx-sender)) (err u109))
    (map-set users tx-sender user-data)
    (map-set user-items tx-sender (list))
    (ok true)))

(define-public (add-clothing-item 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (category (string-ascii 50))
    (size (string-ascii 20))
    (condition (string-ascii 20))
    (image-url (string-ascii 200)))
    (let ((item-id (var-get next-item-id))
          (item-data {
            owner: tx-sender,
            title: title,
            description: description,
            category: category,
            size: size,
            condition: condition,
            image-url: image-url,
            available: true,
            created-at: stacks-block-height
          }))
    (asserts! (is-some (map-get? users tx-sender)) err-user-not-registered)
    (map-set clothing-items item-id item-data)
    (let ((current-items (default-to (list) (map-get? user-items tx-sender))))
        (map-set user-items tx-sender (unwrap! (as-max-len? (append current-items item-id) u100) (err u110))))
    (var-set next-item-id (+ item-id u1))
    (ok item-id)))

(define-public (create-swap-proposal (initiator-item-id uint) (responder-item-id uint))
    (let ((swap-id (var-get next-swap-id))
          (initiator-item (unwrap! (map-get? clothing-items initiator-item-id) err-item-not-found))
          (responder-item (unwrap! (map-get? clothing-items responder-item-id) err-item-not-found)))
    (asserts! (is-some (map-get? users tx-sender)) err-user-not-registered)
    (asserts! (is-eq (get owner initiator-item) tx-sender) err-not-authorized)
    (asserts! (get available initiator-item) err-invalid-swap-status)
    (asserts! (get available responder-item) err-invalid-swap-status)
    (let ((swap-data {
        initiator: tx-sender,
        responder: (get owner responder-item),
        initiator-item: initiator-item-id,
        responder-item: responder-item-id,
        status: "pending",
        created-at: stacks-block-height,
        completed-at: none
    }))
    (map-set swaps swap-id swap-data)
    (var-set next-swap-id (+ swap-id u1))
    (ok swap-id))))

(define-public (accept-swap (swap-id uint))
    (let ((swap-data (unwrap! (map-get? swaps swap-id) err-swap-not-found)))
    (asserts! (is-eq (get responder swap-data) tx-sender) err-not-authorized)
    (asserts! (is-eq (get status swap-data) "pending") err-invalid-swap-status)
    (let ((updated-swap (merge swap-data { status: "accepted" })))
        (map-set swaps swap-id updated-swap)
        (ok true))))

(define-public (complete-swap (swap-id uint))
    (let ((swap-data (unwrap! (map-get? swaps swap-id) err-swap-not-found)))
    (asserts! (or (is-eq (get initiator swap-data) tx-sender) 
                  (is-eq (get responder swap-data) tx-sender)) err-not-authorized)
    (asserts! (is-eq (get status swap-data) "accepted") err-invalid-swap-status)
    (let ((initiator-item-id (get initiator-item swap-data))
          (responder-item-id (get responder-item swap-data))
          (initiator (get initiator swap-data))
          (responder (get responder swap-data)))
        (map-set clothing-items initiator-item-id 
            (merge (unwrap! (map-get? clothing-items initiator-item-id) err-item-not-found) 
                   { owner: responder, available: false }))
        (map-set clothing-items responder-item-id 
            (merge (unwrap! (map-get? clothing-items responder-item-id) err-item-not-found) 
                   { owner: initiator, available: false }))
        (let ((updated-swap (merge swap-data { 
            status: "completed",
            completed-at: (some stacks-block-height)
        })))
            (map-set swaps swap-id updated-swap)
            (try! (mint-reward initiator))
            (try! (mint-reward responder))
            (try! (distribute-style-bonus swap-id initiator responder))
            (try! (update-user-stats initiator))
            (try! (update-user-stats responder))
            (ok true)))))

(define-private (mint-reward (recipient principal))
    (let ((reward-amount (var-get reward-per-swap)))
        (ft-mint? swap-reward reward-amount recipient)))

(define-private (update-user-stats (user principal))
    (let ((user-data (unwrap! (map-get? users user) err-user-not-registered)))
        (map-set users user (merge user-data {
            total-swaps: (+ (get total-swaps user-data) u1),
            reputation: (+ (get reputation user-data) u10)
        }))
        (ok true)))

(define-public (reject-swap (swap-id uint))
    (let ((swap-data (unwrap! (map-get? swaps swap-id) err-swap-not-found)))
    (asserts! (is-eq (get responder swap-data) tx-sender) err-not-authorized)
    (asserts! (is-eq (get status swap-data) "pending") err-invalid-swap-status)
    (let ((updated-swap (merge swap-data { status: "rejected" })))
        (map-set swaps swap-id updated-swap)
        (ok true))))

(define-public (set-item-availability (item-id uint) (available bool))
    (let ((item-data (unwrap! (map-get? clothing-items item-id) err-item-not-found)))
    (asserts! (is-eq (get owner item-data) tx-sender) err-not-authorized)
    (map-set clothing-items item-id (merge item-data { available: available }))
    (ok true)))

(define-public (set-reward-amount (new-amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set reward-per-swap new-amount)
        (ok true)))

(define-read-only (get-user (user principal))
    (map-get? users user))

(define-read-only (get-item (item-id uint))
    (map-get? clothing-items item-id))

(define-read-only (get-swap (swap-id uint))
    (map-get? swaps swap-id))

(define-read-only (get-user-items (user principal))
    (map-get? user-items user))

(define-read-only (get-available-items)
    (ok (var-get next-item-id)))

(define-read-only (get-total-swaps)
    (ok (var-get next-swap-id)))

(define-read-only (get-reward-amount)
    (ok (var-get reward-per-swap)))

(define-public (set-item-style-attributes
    (item-id uint)
    (style-type (string-ascii 30))
    (color-palette (string-ascii 30))
    (formality-level uint)
    (season (string-ascii 20))
    (trend-score uint))
    (let ((item (unwrap! (map-get? clothing-items item-id) err-item-not-found)))
        (asserts! (is-eq (get owner item) tx-sender) err-not-authorized)
        (asserts! (<= formality-level u10) err-invalid-style-score)
        (asserts! (<= trend-score u100) err-invalid-style-score)
        (map-set item-style-attributes item-id {
            style-type: style-type,
            color-palette: color-palette,
            formality-level: formality-level,
            season: season,
            trend-score: trend-score
        })
        (ok true)))

(define-public (set-user-style-preferences
    (preferred-style (string-ascii 30))
    (color-harmony uint)
    (versatility-score uint)
    (eco-conscious-rating uint))
    (begin
        (asserts! (is-some (map-get? users tx-sender)) err-user-not-registered)
        (asserts! (<= color-harmony u100) err-invalid-style-score)
        (asserts! (<= versatility-score u100) err-invalid-style-score)
        (asserts! (<= eco-conscious-rating u100) err-invalid-style-score)
        (map-set user-style-preferences tx-sender {
            preferred-style: preferred-style,
            color-harmony: color-harmony,
            versatility-score: versatility-score,
            eco-conscious-rating: eco-conscious-rating
        })
        (ok true)))

(define-private (calculate-style-compatibility (item1-id uint) (item2-id uint))
    (match (map-get? item-style-attributes item1-id)
        item1-style
        (match (map-get? item-style-attributes item2-id)
            item2-style
            (let (
                (formality-diff (if (> (get formality-level item1-style) (get formality-level item2-style))
                                    (- (get formality-level item1-style) (get formality-level item2-style))
                                    (- (get formality-level item2-style) (get formality-level item1-style))))
                (trend-avg (/ (+ (get trend-score item1-style) (get trend-score item2-style)) u2))
                (season-match (if (is-eq (get season item1-style) (get season item2-style)) u20 u0))
                (style-match (if (is-eq (get style-type item1-style) (get style-type item2-style)) u30 u10))
                (color-match (if (is-eq (get color-palette item1-style) (get color-palette item2-style)) u20 u10))
            )
                (let ((base-score (+ (+ (+ style-match color-match) season-match) trend-avg)))
                    (if (<= formality-diff u2)
                        (if (> base-score u90) style-match-perfect
                            (if (> base-score u70) style-match-excellent
                                (if (> base-score u50) style-match-good style-match-fair)))
                        (if (> base-score u60) style-match-good style-match-fair))))
            u40)
        u40))

(define-private (calculate-style-bonus (compatibility-score uint) (base-reward uint))
    (if (>= compatibility-score style-match-excellent)
        (/ (* base-reward (* style-bonus-multiplier compatibility-score)) u100)
        (if (>= compatibility-score style-match-good)
            (/ (* base-reward compatibility-score) u100)
            u0)))

(define-private (distribute-style-bonus (swap-id uint) (initiator principal) (responder principal))
    (match (map-get? swaps swap-id)
        swap-data
        (let (
            (compatibility (calculate-style-compatibility 
                           (get initiator-item swap-data) 
                           (get responder-item swap-data)))
            (bonus-amount (calculate-style-bonus compatibility (var-get reward-per-swap)))
        )
            (if (> bonus-amount u0)
                (begin
                    (map-set swap-style-scores swap-id {
                        compatibility-score: compatibility,
                        bonus-earned: bonus-amount,
                        match-category: (if (>= compatibility style-match-excellent) "excellent" 
                                          (if (>= compatibility style-match-good) "good" "fair"))
                    })
                    (var-set total-style-matches (+ (var-get total-style-matches) u1))
                    (if (>= compatibility style-match-perfect)
                        (var-set perfect-matches (+ (var-get perfect-matches) u1))
                        true)
                    (try! (ft-mint? swap-reward bonus-amount initiator))
                    (try! (ft-mint? swap-reward bonus-amount responder))
                    (ok u0))
                (ok u0)))
        (ok u0)))

(define-read-only (get-style-compatibility-score (item1-id uint) (item2-id uint))
    (ok (calculate-style-compatibility item1-id item2-id)))

(define-read-only (get-swap-style-score (swap-id uint))
    (map-get? swap-style-scores swap-id))

(define-read-only (get-item-style-attributes (item-id uint))
    (map-get? item-style-attributes item-id))

(define-read-only (get-user-style-preferences (user principal))
    (map-get? user-style-preferences user))

(define-read-only (get-style-match-stats)
    (ok {
        total-matches: (var-get total-style-matches),
        perfect-matches: (var-get perfect-matches),
        perfect-ratio: (if (> (var-get total-style-matches) u0)
                         (/ (* (var-get perfect-matches) u100) (var-get total-style-matches))
                         u0)
    }))

(define-read-only (preview-swap-bonus (item1-id uint) (item2-id uint))
    (let (
        (compatibility (calculate-style-compatibility item1-id item2-id))
        (potential-bonus (calculate-style-bonus compatibility (var-get reward-per-swap)))
    )
        (ok {
            compatibility-score: compatibility,
            potential-bonus: potential-bonus,
            match-level: (if (>= compatibility style-match-perfect) "perfect"
                           (if (>= compatibility style-match-excellent) "excellent"
                             (if (>= compatibility style-match-good) "good" 
                               (if (>= compatibility style-match-fair) "fair" "low"))))
        })))
