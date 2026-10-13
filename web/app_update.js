window.cafeApplyWebUpdate = async function () {
  if ('serviceWorker' in navigator) {
    const registration = await navigator.serviceWorker.getRegistration();
    if (registration) await registration.update();
  }
  window.location.reload();
};
