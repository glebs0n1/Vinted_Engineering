require_relative 'models/counts_repository'
require_relative 'models/invalid_order'
require_relative 'models/order'
require_relative 'processors/order_processor'

SIZES = %i[S M L].freeze
L_LP_RULE_THRESHOLD = 3
PROVIDERS = {
  LP: {
    S: 1.5,
    M: 4.9,
    L: 6.9
  },
  MR: {
    S: 2,
    M: 3,
    L: 4
  }
}.freeze
LOWEST_S_PRICE = PROVIDERS.values.map { |prices| prices[:S] }.min
SEPARATOR = ' '
MONTHLY_DISCOUNT_LIMIT = 10

File.open('output.txt', 'w') do |output_file|
  $stdout = output_file

OrderProcessor.new.run
$stdout = STDOUT
end
