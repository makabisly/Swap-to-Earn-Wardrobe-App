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
(define-constant err-swap-not-completed (err u109))
(define-constant err-already-rated (err u110))
(define-constant err-invalid-rating (err u111))
(define-constant err-cannot-rate-self (err u112))
(define-constant err-user-already-registered (err u113))
(define-constant err-max-items-reached (err u114))

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

(define-map swap-ratings {swap-id: uint, rater: principal} {
    rating: uint,
    review: (string-ascii 500),
    rated-user: principal,
    created-at: uint
})

(define-map user-rating-stats principal {
    total-ratings: uint,
    sum-ratings: uint,
    five-star: uint,
    four-star: uint,
    three-star: uint,
    two-star: uint,
    one-star: uint
})

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
    (asserts! (is-none (map-get? users tx-sender)) err-user-already-registered)
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
        (map-set user-items tx-sender (unwrap! (as-max-len? (append current-items item-id) u100) err-max-items-reached)))
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

(define-public (rate-swap-partner (swap-id uint) (rating uint) (review (string-ascii 500)))
    (let ((swap-data (unwrap! (map-get? swaps swap-id) err-swap-not-found))
          (initiator (get initiator swap-data))
          (responder (get responder swap-data)))
    (asserts! (is-eq (get status swap-data) "completed") err-swap-not-completed)
    (asserts! (or (is-eq tx-sender initiator) (is-eq tx-sender responder)) err-not-authorized)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (is-none (map-get? swap-ratings {swap-id: swap-id, rater: tx-sender})) err-already-rated)
    (let ((rated-user (if (is-eq tx-sender initiator) responder initiator)))
        (asserts! (not (is-eq tx-sender rated-user)) err-cannot-rate-self)
        (map-set swap-ratings {swap-id: swap-id, rater: tx-sender} {
            rating: rating,
            review: review,
            rated-user: rated-user,
            created-at: stacks-block-height
        })
        (unwrap-panic (update-rating-stats rated-user rating))
        (ok true))))

(define-private (update-rating-stats (user principal) (rating uint))
    (let ((current-stats (default-to {
            total-ratings: u0,
            sum-ratings: u0,
            five-star: u0,
            four-star: u0,
            three-star: u0,
            two-star: u0,
            one-star: u0
        } (map-get? user-rating-stats user))))
    (map-set user-rating-stats user {
        total-ratings: (+ (get total-ratings current-stats) u1),
        sum-ratings: (+ (get sum-ratings current-stats) rating),
        five-star: (+ (get five-star current-stats) (if (is-eq rating u5) u1 u0)),
        four-star: (+ (get four-star current-stats) (if (is-eq rating u4) u1 u0)),
        three-star: (+ (get three-star current-stats) (if (is-eq rating u3) u1 u0)),
        two-star: (+ (get two-star current-stats) (if (is-eq rating u2) u1 u0)),
        one-star: (+ (get one-star current-stats) (if (is-eq rating u1) u1 u0))
    })
    (ok true)))

(define-read-only (get-swap-rating (swap-id uint) (rater principal))
    (map-get? swap-ratings {swap-id: swap-id, rater: rater}))

(define-read-only (get-user-rating-stats (user principal))
    (map-get? user-rating-stats user))

(define-read-only (get-user-average-rating (user principal))
    (match (map-get? user-rating-stats user)
        stats 
        (if (> (get total-ratings stats) u0)
            (ok (/ (* (get sum-ratings stats) u100) (get total-ratings stats)))
            (ok u0))
        (ok u0)))

(define-read-only (get-user-rating-breakdown (user principal))
    (match (map-get? user-rating-stats user)
        stats
        (ok {
            total-ratings: (get total-ratings stats),
            average-rating: (if (> (get total-ratings stats) u0)
                (/ (* (get sum-ratings stats) u100) (get total-ratings stats))
                u0),
            five-star: (get five-star stats),
            four-star: (get four-star stats),
            three-star: (get three-star stats),
            two-star: (get two-star stats),
            one-star: (get one-star stats)
        })
        (ok {
            total-ratings: u0,
            average-rating: u0,
            five-star: u0,
            four-star: u0,
            three-star: u0,
            two-star: u0,
            one-star: u0
        })))
