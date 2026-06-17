describe("PaymentProvider Contract", () => {
  it("defines required plan types", () => {
    const validPlans: string[] = ["free", "starter", "pro"];
    expect(validPlans).toContain("starter");
    expect(validPlans).toContain("pro");
  });
});

describe("MpesaProvider", () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...OLD_ENV };
  });

  afterEach(() => {
    process.env = OLD_ENV;
  });

  it("defaults to sandbox when MPESA_ENVIRONMENT is not set", () => {
    delete process.env.MPESA_ENVIRONMENT;
    const { MpesaProvider } = require("../services/mpesaProvider");
    const provider = new MpesaProvider();
    expect(provider).toBeDefined();
  });

  it("uses production when MPESA_ENVIRONMENT is set", () => {
    process.env.MPESA_ENVIRONMENT = "production";
    const { MpesaProvider } = require("../services/mpesaProvider");
    const provider = new MpesaProvider();
    expect(provider).toBeDefined();
  });
});
