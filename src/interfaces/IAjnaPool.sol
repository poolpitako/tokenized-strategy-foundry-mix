// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

interface IAjnaPool {
  /**
   *  @notice Called by lenders to add an amount of credit at a specified price bucket.
   *  @param  amount_           The amount of quote token to be added by a lender (`WAD` precision).
   *  @param  index_            The index of the bucket to which the quote tokens will be added.
   *  @param  expiry_           Timestamp after which this transaction will revert, preventing inclusion in a block with unfavorable price.
   *  @param  revertIfBelowLup_ The tx will revert if price of the bucket to which the quote tokens will be added is below `LUP` price (and avoid paying fee for deposit below `LUP`).
   *  @return bucketLP_         The amount of `LP` changed for the added quote tokens (`WAD` precision).
   */
  function addQuoteToken(
      uint256 amount_,
      uint256 index_,
      uint256 expiry_,
      bool    revertIfBelowLup_
  ) external returns (uint256 bucketLP_);

  /**
    *  @notice Called by lenders to remove an amount of credit at a specified price bucket.
    *  @param  maxAmount_     The max amount of quote token to be removed by a lender (`WAD` precision).
    *  @param  index_         The bucket index from which quote tokens will be removed.
    *  @return removedAmount_ The amount of quote token removed (`WAD` precision).
    *  @return redeemedLP_    The amount of `LP` used for removing quote tokens amount (`WAD` precision).
    */
  function removeQuoteToken(
      uint256 maxAmount_,
      uint256 index_
  ) external returns (uint256 removedAmount_, uint256 redeemedLP_);


  /**
   *  @notice Called by lenders to move an amount of credit from a specified price bucket to another specified price bucket.
   *  @param  maxAmount_        The maximum amount of quote token to be moved by a lender (`WAD` precision).
   *  @param  fromIndex_        The bucket index from which the quote tokens will be removed.
   *  @param  toIndex_          The bucket index to which the quote tokens will be added.
   *  @param  expiry_           Timestamp after which this transaction will revert, preventing inclusion in a block with unfavorable price.
   *  @param  revertIfBelowLup_ The tx will revert if quote token is moved from above the `LUP` to below the `LUP` (and avoid paying fee for move below `LUP`).
   *  @return fromBucketLP_     The amount of `LP` moved out from bucket (`WAD` precision).
   *  @return toBucketLP_       The amount of `LP` moved to destination bucket (`WAD` precision).
   *  @return movedAmount_      The amount of quote token moved (`WAD` precision).
   */
  function moveQuoteToken(
      uint256 maxAmount_,
      uint256 fromIndex_,
      uint256 toIndex_,
      uint256 expiry_,
      bool    revertIfBelowLup_
  ) external returns (uint256 fromBucketLP_, uint256 toBucketLP_, uint256 movedAmount_);


  /**
   *  @notice Returns the address of the pool's quote token.
   */
  function quoteTokenAddress() external pure returns (address);

}
