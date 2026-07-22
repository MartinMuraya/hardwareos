import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

const makeStub = () => onCall(() => {
  return { status: "stubbed", message: "Function temporarily stubbed to prevent deletion during deployment." };
});

const makeScheduleStub = () => onSchedule("every 24 hours", () => {
  console.log("Scheduled function temporarily stubbed to prevent deletion.");
});

export const deleteCustomer = makeStub();
export const deleteCustomerAddress = makeStub();
export const deleteDeliveryZone = makeStub();
export const deleteProduct = makeStub();
export const deleteStorefrontCategory = makeStub();
export const deleteSupplier = makeStub();
export const disableStorefront = makeStub();
export const enableStorefront = makeStub();
export const getActiveHolds = makeStub();
export const getCart = makeStub();
export const getCarts = makeStub();
export const getCheckoutAttempts = makeStub();
export const getCommerceAnalytics = makeStub();
export const getCommerceTemplates = makeStub();
export const getCustomerAddresses = makeStub();
export const getDeliveryZones = makeStub();
export const getOnlineOrder = makeStub();
export const getOnlineOrders = makeStub();
export const getOrderMetrics = makeStub();
export const getOrderReturns = makeStub();
export const getPublicCategories = makeStub();
export const getPublicProductDetails = makeStub();
export const getPublicProducts = makeStub();
export const getPublicStorefront = makeStub();
export const getStorefrontCategories = makeStub();
export const getStorefrontSettings = makeStub();
export const processFailedSyncRetries = makeScheduleStub();
export const processRefund = makeStub();
export const processStaleCheckouts = makeScheduleStub();
export const recordCheckoutAttempt = makeStub();
export const rejectReturn = makeStub();
export const releaseExpiredHolds = makeScheduleStub();
export const releaseStockHold = makeStub();
export const removeFromCart = makeStub();
export const requestReturn = makeStub();
export const resetCommerceTemplate = makeStub();
export const retryCheckout = makeStub();
export const rollupAnalytics = makeScheduleStub();
export const saveCustomerAddress = makeStub();
export const scanAbandonedCarts = makeScheduleStub();
export const trackEvent = makeStub();
export const updateCartQuantity = makeStub();
export const updateCommerceTemplate = makeStub();
export const updateDeliveryZone = makeStub();
export const updateOrderStatus = makeStub();
export const updateStorefrontCategory = makeStub();
export const updateStorefrontSettings = makeStub();
