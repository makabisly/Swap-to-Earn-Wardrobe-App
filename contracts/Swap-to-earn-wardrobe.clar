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
