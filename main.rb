require 'date'

# (MR) - Mondial Relay
# (LP) - La Poste
# (S) - Small, a popular option to ship jewelry
# (M) - Medium - clothes and similar items
# (L) - Large - mostly shoes

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

# Holds counts necessary for order processing.
class CountsRepository
  def initialize
    @counts = {
      l_lp_count: {},
      monthly_total: {}
    }.freeze
  end

  def l_lp_count(year_month)
    counts[:l_lp_count][year_month] ||= 0
  end

  def l_lp_threshold?(year_month)
    counts[:l_lp_count][year_month] == L_LP_RULE_THRESHOLD
  end

  def increment_l_lp_count(year_month)
    counts[:l_lp_count][year_month] = l_lp_count(year_month) + 1
  end

  def monthly_total(year_month)
    counts[:monthly_total][year_month] ||= 0
  end

  def add_monthly_total(year_month, discount)
    counts[:monthly_total][year_month] += discount
  end

  private

  attr_reader :counts
end

# NullObject pattern
class InvalidOrder
  attr_accessor :discount, :size

  def initialize(order_args)
    @line = order_args.join(SEPARATOR)
    @size = false
    @discount = 0
  end

  def year_month
    false
  end

  def large_la_poste?
    false
  end

  def to_s
    "#{line} Ignored"
  end

  private

  attr_reader :line
end

# Contains details for an item to be sent via parcel service.
class Order
  attr_reader :date, :size, :operator, :price
  attr_accessor :discount

  def initialize(date, size, operator)
    @date = date
    @size = size
    @operator = operator
    @price = PROVIDERS[operator][size]
  end

  def self.from(order_args)
    return InvalidOrder.new(order_args) unless valid?(order_args)

    Order.new(Date.iso8601(order_args[0]), order_args[1].to_sym, order_args[2].to_sym)
  end

  def self.valid?(order_args)
    Date.iso8601(order_args[0]) &&
      SIZES.include?(order_args[1].to_sym) &&
      PROVIDERS.keys.include?(order_args[2].to_sym)
  rescue ArgumentError
    false
  end

  def to_s
    "#{date} #{size} #{operator} #{'%.2f' % format_price} #{format_discount}"
  end

  def year_month
    date.strftime('%Y-%m')
  end

  def large_la_poste?
    operator == :LP && size == :L
  end

  private

  def format_price
    return price - discount if discount.positive?

    price
  end

  def format_discount
    discount.positive? ? '%.2f' % discount : '-'
  end
end

# Holds the logic for processing orders and calculating discounts.
class OrderProcessor
  attr_reader :counts, :lowest_s_price, :orders_file

  DISCOUNT_RULES = {
    ->(order) { order.size == :S } => ->(order, _counts) { order.price - LOWEST_S_PRICE },
    ->(order) { order.large_la_poste? } => lambda do |order, counts|
      counts.increment_l_lp_count(order.year_month)
      counts.l_lp_threshold?(order.year_month) ? PROVIDERS[:LP][:L] : 0
    end,
    ->(_order) { true } => ->(_order, _counts) { 0 }
  }.freeze

  def initialize(orders_file = 'input.txt')
    @orders_file = orders_file
    @counts = CountsRepository.new
  end

  def run
    File.readlines(orders_file)
        .map { |line| line.split(SEPARATOR) }
        .map { |order_args| Order.from(order_args) }
        .each { |order| apply_discount(order) }
        .each { |order| puts order }
  end

  private

  def apply_discount(order)
    rule = DISCOUNT_RULES.find { |predicate, _rule| predicate.call(order) }[1]
    limit_discount(order, rule.call(order, counts))
  end

  def limit_discount(order, discount)
    monthly_total = counts.monthly_total(order.year_month) + discount
    discount -= (monthly_total - MONTHLY_DISCOUNT_LIMIT) if monthly_total >= MONTHLY_DISCOUNT_LIMIT
    counts.add_monthly_total(order.year_month, discount)
    order.discount = discount
  end
end

# Run the order processor
OrderProcessor.new.run
