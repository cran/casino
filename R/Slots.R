#' Slots R6 Class
#' @importFrom magrittr "%>%"
#' @examples
#' set.seed(101315)
#' setup()
#'
#' # start the slot machine
#' x <- Slots$new(who = "Player 1", bet = 10)
#'
#' # play 1 game
#' x$play()
#'
#' # play >1 game at a time
#' x$play(spins = 3)
#'
#' # clean-up
#' delete()
#' @export
Slots <- R6::R6Class("Slots",
  public = list(

    bet = NULL,
    who = NULL,
    reel = NULL,
    reels = NULL,
    turn = NULL,

    verbose = NULL,
    sound = NULL,

    # -- setup machine
    initialize = function(who = NA, bet = 10, verbose = TRUE, sound = TRUE) {
      self$who <- Player$new(who)
      self$bet <- bet
      self$verbose <- verbose
      self$sound <- sound
      private$make_reel()
    },

    # -- print
    print = function(...) {
      if (self$turn == 0) {
        cat("Slot Machine: \n")
        cat("Player: ", self$who$name, "\n", sep = "")
        cat("Bank: ", self$who$balance, "\n", sep = "")
        cat(" Start a new game with `play().", "\n", sep = "")
      } else if (self$turn == 1) {
        score <- tail(self$who$history, 1)
        cat(" Reels: ", self$print_reels(), "\n", sep = "")
        cat("   You ", ifelse(score$net >= 0, "won", "lost"), " ", score$net, "!\n", sep = "")
        cat("   Now you have ", self$who$balance, " in your account.\n", sep = "")
      }
      invisible(self)
    },

    # -- print reel in terminal using crayon highlighting
    print_reels = function() {
      reels <- crayon::bold(paste(self$reels, collapse = " "))
      switch(length(unique(self$reels)),
        crayon::bgGreen(reels),
        crayon::bgYellow(reels),
        crayon::bgRed(reels)
        )
    },

    # -- gameplay
    play = function(bet = self$bet, spins = 1) {
      for (i in 1:spins) {
        self$bet <- self$who$bet(bet)
        private$spin()
        private$end_game()
      }
      cat(crayon::italic("Do you want to `play()` again?", "\n", sep = ""))
      invisible(self)
    },

    # -- see payout table
    get_payout = function(bet = self$bet) {
      dplyr::mutate(
        private$payout(),
        win = bet * multiplier
      )
    }
  ),

  private = list(

    # -- create a reel
    make_reel = function() {
      reel <- c("!", "@", "#", "$", "%", "^", "&", "*")
      self$reel <- sample(rep(reel, (1:length(reel)) ^ 3))
      self$turn <- 0
    },

    # -- spin reels
    spin = function() {
      self$reels <- sample(self$reel, 3)
      invisible(self)
    },

    # -- payout structure
    payout = function() {
      freq <- table(self$reel)
      tibble::tibble(
        outcome = purrr::map_chr(names(freq), ~paste(rep(.x, 3), collapse = " ")),
        multiplier = as.numeric(floor(1 / ((freq / sum(freq)) ^ 3)))
      ) %>%
        dplyr::arrange(desc(multiplier))
    },

    # -- score of a single game/spin
    score = function() {
      dplyr::left_join(
        tibble::tibble(outcome = paste(self$reels, collapse = " ")),
        private$payout(),
        by = "outcome"
      ) %>%
        dplyr::mutate(
          multiplier = ifelse(is.na(multiplier), 0, multiplier),
          bet = self$bet,
          win = bet * multiplier,
          net = win - bet
        )
    },

    # -- end game and record results
    end_game = function() {
      score <- private$score()
      self$who$record(game = "Slots", outcome = score$outcome, bet = score$bet, win = score$win, net = score$net)
      self$turn <- 1
      if (self$sound && score$win > 0)
        play_sound()
      if (self$verbose)
        print(self)
    }

  )
)