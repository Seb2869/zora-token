import { Address, TypedDataDefinition } from "viem";

const TypedDataDomain = "ZoraTokenCommunityClaim";
const TypedDataVersion = "1";

type PermitClaimTypedDataDefinition = TypedDataDefinition<
  {
    ClaimWithSignature: [
      { name: "user"; type: "address" },
      { name: "claimTo"; type: "address" },
      { name: "deadline"; type: "uint256" },
    ];
  },
  "ClaimWithSignature"
>;
// typed data domain:
export const permitClaimTypedDataDefinition = ({
  message,
  chainId,
  claimContract,
}: {
  message: {
    user: Address;
    claimTo: Address;
    deadline: bigint;
  };
  chainId: number;
  claimContract: Address;
}) => {
  const typesAndMessage: Omit<PermitClaimTypedDataDefinition, "domain"> = {
    types: {
      ClaimWithSignature: [
        { name: "user", type: "address" },
        { name: "claimTo", type: "address" },
        { name: "deadline", type: "uint256" },
      ],
    },
    message,
    primaryType: "ClaimWithSignature",
  };

  return {
    ...typesAndMessage,
    domain: {
      chainId,
      name: TypedDataDomain,
      version: TypedDataVersion,
      verifyingContract: claimContract,
    },
  };
};

type SetAllocationsTypedDataDefinition = TypedDataDefinition<
  {
    SetAllocations: [
      { name: "packedData"; type: "bytes32[]" },
      { name: "nonce"; type: "bytes32" },
    ];
  },
  "SetAllocations"
>;

export const setAllocationsTypedDataDefinition = ({
  message,
  chainId,
  claimContract,
}: {
  message: {
    packedData: `0x${string}`[];
    nonce: `0x${string}`;
  };
  chainId: number;
  claimContract: Address;
}) => {
  const typesAndMessage: Omit<SetAllocationsTypedDataDefinition, "domain"> = {
    types: {
      SetAllocations: [
        { name: "packedData", type: "bytes32[]" },
        { name: "nonce", type: "bytes32" },
      ],
    },
    message,
    primaryType: "SetAllocations",
  };

  return {
    ...typesAndMessage,
    domain: {
      chainId,
      name: TypedDataDomain,
      version: TypedDataVersion,
      verifyingContract: claimContract,
    },
  };
};
